#requires -Version 7.0
# Copyright (c) 2026 Tuomo Kriikkula
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

<#
.SYNOPSIS
Locates the Rising Storm 2 UnrealScript toolchain and builds AircraftMod.

.DESCRIPTION
Use `sync` to locate the Steam installation and cache the absolute editor and
SDK-source paths. `build` uses that cache, checks the per-user ROEditor.ini
mod-package setting, and invokes VNEditor through the included dual-mode
console-output wrapper. It does not patch the editor or poll logs or process
status.

.EXAMPLE
.\build.ps1

.EXAMPLE
.\build.ps1 sync

.EXAMPLE
.\build.ps1 sync --editor-path "O:\Rising Storm 2\Binaries\Win64\VNEditor.exe" --sdk-source-path "O:\Rising Storm 2\Development\Src"

.EXAMPLE
.\build.ps1 build --release
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)]
    [string]$Command = '',

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$CommandArguments = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:SteamAppId = '418460'
$script:ExpectedGameName = 'Rising Storm 2: Vietnam'
$script:ConsoleWrapperProtocol = 'UE3-DualModeNamedPipe'
$script:ConsoleWrapperVersion = 1
$script:BuildDirectory = Join-Path $PSScriptRoot '.build'
$script:CachePath = Join-Path $script:BuildDirectory 'toolchain.json'
$script:NoColor = -not [string]::IsNullOrEmpty($env:NO_COLOR)

function Write-BuildLog {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('info', 'success', 'warning', 'error')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $line = '{0}: {1}' -f $Level, $Message
    if (-not $script:NoColor -and $Host.UI.SupportsVirtualTerminal) {
        $colorCode = switch ($Level) {
            'info' { '36' }
            'success' { '32' }
            'warning' { '33' }
            'error' { '31' }
        }
        $line = '{0}[{1}m{2}{0}[0m' -f [char]27, $colorCode, $line
    }

    Write-Information -MessageData $line -InformationAction Continue
}

function Show-Usage {
    $usage = @'
Usage: .\build.ps1 <command> [options]

Commands:
  sync    Locate the RS2 editor and UnrealScript sources; refresh the local cache.
  build   Compile AircraftMod using the cached editor and output wrapper.
  help    Show detailed command and option help.

Run .\build.ps1 help for details. With no command, this short usage is shown.
'@
    Write-Output $usage
}

function Show-Help {
    $help = @'
AircraftMod UnrealScript build tool

Commands:
  .\build.ps1
      Print short usage.

  .\build.ps1 help
      Show this help.

  .\build.ps1 sync [--editor-path <path>] [--sdk-source-path <path>] [--no-color]
      Locate VNEditor.exe and the RS2 Development\Src directory, then save their
      absolute paths and editor identity in .build\toolchain.json.
      Steam discovery reads the Windows Steam registry location, Steam library
      folders, and the Rising Storm 2 app manifest. Explicit paths can be used
      for nonstandard installations or when discovery is ambiguous.

  .\build.ps1 build [--release] [--no-color]
      Use the cached toolchain. If no cache exists, discover and cache it first.
      A stale cache is not silently refreshed; run `sync`.
      Before compiling, verify `ModPackages=AircraftMod` under `[ModPackages]`
      in the user's Documents\My Games\Rising Storm 2\ROGame\Config\ROEditor.ini.
      The normal build arguments are "make -useunpublished -FORCELOGFLUSH".
      The .NET 10 wrapper streams VNEditor's dual-mode output pipe and waits for
      both pipe closure and process exit. The original editor is not modified.
      --release adds -stripsource. The expected output is
      Documents\My Games\Rising Storm 2\ROGame\Unpublished\CookedPC\Script\AircraftMod.u.

Wrapper setup:
  Build the .NET helper separately before the first script build:
  dotnet build .\tools\build\VNEditorConsoleWrapper.csproj --configuration Release --output .\.build\VNEditorConsoleWrapper
  `build.ps1` never runs `dotnet build`; it only builds UnrealScript code.

Cache behavior:
  The local cache is .build\toolchain.json and is gitignored. `sync` refreshes
  paths; a cached editor or source path that no longer validates requires an
  explicit `sync`.
  The cache records the editor's identity and the version of the dual-mode
  named-pipe protocol used by the local console wrapper. VNEditor.exe is not
  copied or modified.

Editor completion:
  `build` requires the prebuilt wrapper executable in the ignored .build
  directory, then invokes the original VNEditor.exe. The wrapper starts the
  editor suspended, establishes its PID-specific output pipe, and resumes it.
  It forwards UTF-16 output asynchronously and waits for pipe closure and
  editor exit without polling.

Options:
  --editor-path       VNEditor.exe path; accepted by `sync`.
  --sdk-source-path   RS2 Development\Src path; accepted by `sync`.
  --release           Add -stripsource to the compiler arguments.
  --no-color          Disable colored diagnostics. The NO_COLOR environment
                      variable has the same effect.
  --dry-run           Preview cache writes and editor launches without
                      performing them.
  --verbose           Show diagnostic details such as the editor SHA-256.

PowerShell common parameters are also available: -Verbose, -WhatIf, and
-Confirm.
'@
    Write-Output $help
}

function ConvertFrom-VdfValue {
    param([Parameter(Mandatory)][string]$Value)

    return $Value.Replace('\\', '\').Replace('\"', '"')
}

function Get-VdfStringValue {
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$Key
    )

    $pattern = '(?m)^\s*"' + [regex]::Escape($Key) + '"\s+"(?<value>(?:\\.|[^"\\])*)"\s*$'
    $match = [regex]::Match($Content, $pattern)
    if (-not $match.Success) {
        return $null
    }

    return ConvertFrom-VdfValue -Value $match.Groups['value'].Value
}

function Add-ExistingSteamRoot {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.HashSet[string]]$Roots,

        [Parameter(Mandatory)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $expandedPath = [Environment]::ExpandEnvironmentVariables($Path)
    $fullPath = [IO.Path]::GetFullPath($expandedPath)
    if (Test-Path -LiteralPath $fullPath -PathType Container) {
        [void]$Roots.Add($fullPath)
    }
}

function Get-SteamLibraryRoot {
    $roots = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    $registryPaths = @(
        'HKCU:\Software\Valve\Steam',
        'HKLM:\SOFTWARE\Valve\Steam',
        'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam'
    )

    foreach ($registryPath in $registryPaths) {
        if (-not (Test-Path -LiteralPath $registryPath)) {
            continue
        }

        $properties = Get-ItemProperty -LiteralPath $registryPath
        foreach ($propertyName in @('SteamPath', 'InstallPath')) {
            $property = $properties.PSObject.Properties[$propertyName]
            if ($null -eq $property) {
                continue
            }

            $value = [string]$property.Value
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                Add-ExistingSteamRoot -Roots $roots -Path $value
            }
        }

        $steamExeProperty = $properties.PSObject.Properties['SteamExe']
        $steamExe = if ($null -ne $steamExeProperty) {
            [string]$steamExeProperty.Value
        }
        else {
            ''
        }
        if (-not [string]::IsNullOrWhiteSpace($steamExe)) {
            Add-ExistingSteamRoot -Roots $roots -Path (Split-Path -Parent $steamExe)
        }
    }

    foreach ($fallback in @(
            (Join-Path ${env:ProgramFiles(x86)} 'Steam'),
            (Join-Path $env:ProgramFiles 'Steam')
        )) {
        if (-not [string]::IsNullOrWhiteSpace($fallback)) {
            Add-ExistingSteamRoot -Roots $roots -Path $fallback
        }
    }

    $steamInstallRoots = @($roots)
    foreach ($steamRoot in $steamInstallRoots) {
        $libraryFile = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
        if (-not (Test-Path -LiteralPath $libraryFile -PathType Leaf)) {
            continue
        }

        $content = Get-Content -LiteralPath $libraryFile -Raw
        $modernPathPattern = '(?m)^\s*"path"\s+"(?<value>(?:\\.|[^"\\])*)"\s*$'
        foreach ($match in [regex]::Matches($content, $modernPathPattern)) {
            Add-ExistingSteamRoot -Roots $roots -Path (
                ConvertFrom-VdfValue -Value $match.Groups['value'].Value
            )
        }

        # Older Steam library files stored a rooted path directly under a numeric key.
        $legacyPathPattern = '(?m)^\s*"\d+"\s+"(?<value>(?:\\.|[^"\\])*)"\s*$'
        foreach ($match in [regex]::Matches($content, $legacyPathPattern)) {
            $path = ConvertFrom-VdfValue -Value $match.Groups['value'].Value
            if ([IO.Path]::IsPathRooted($path)) {
                Add-ExistingSteamRoot -Roots $roots -Path $path
            }
        }
    }

    return @($roots)
}

function Find-RisingStorm2Install {
    $installMatches = [System.Collections.Generic.List[object]]::new()
    $libraryRoots = @(Get-SteamLibraryRoot)
    if ($libraryRoots.Count -eq 0) {
        throw 'Steam was not found. Run sync with --editor-path and --sdk-source-path.'
    }

    foreach ($libraryRoot in $libraryRoots) {
        $steamApps = Join-Path $libraryRoot 'steamapps'
        $manifestPath = Join-Path $steamApps "appmanifest_$($script:SteamAppId).acf"
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
            continue
        }

        $manifest = Get-Content -LiteralPath $manifestPath -Raw
        $appId = Get-VdfStringValue -Content $manifest -Key 'appid'
        $gameName = Get-VdfStringValue -Content $manifest -Key 'name'
        $installDirectory = Get-VdfStringValue -Content $manifest -Key 'installdir'
        if ($appId -ne $script:SteamAppId -or $gameName -ne $script:ExpectedGameName) {
            continue
        }
        if ([string]::IsNullOrWhiteSpace($installDirectory)) {
            continue
        }

        $gameRoot = Join-Path (Join-Path $steamApps 'common') $installDirectory
        $editorPath = Join-Path $gameRoot 'Binaries\Win64\VNEditor.exe'
        $sdkSourcePath = Join-Path $gameRoot 'Development\Src'
        if ((Test-Path -LiteralPath $editorPath -PathType Leaf) -and
            (Test-Path -LiteralPath $sdkSourcePath -PathType Container)) {
            $installMatches.Add([pscustomobject]@{
                    GameRoot      = [IO.Path]::GetFullPath($gameRoot)
                    EditorPath    = [IO.Path]::GetFullPath($editorPath)
                    SdkSourcePath = [IO.Path]::GetFullPath($sdkSourcePath)
                    SteamLibrary  = $libraryRoot
                })
        }
    }

    if ($installMatches.Count -eq 0) {
        throw "Steam was found, but no installed $($script:ExpectedGameName) editor and Development\Src pair was found. Run sync with explicit paths."
    }
    if ($installMatches.Count -gt 1) {
        $candidateList = ($installMatches | ForEach-Object { "  '$($_.GameRoot)'" }) -join [Environment]::NewLine
        throw "Multiple valid Rising Storm 2 installs were found. Select one with sync --editor-path and --sdk-source-path:`n$candidateList"
    }

    return $installMatches[0]
}

function Resolve-EditorPath {
    param([Parameter(Mandatory)][string]$Path)

    $expandedPath = [Environment]::ExpandEnvironmentVariables($Path)
    $fullPath = [IO.Path]::GetFullPath($expandedPath)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Editor executable does not exist: '$fullPath'"
    }
    if ([IO.Path]::GetFileName($fullPath) -ine 'VNEditor.exe') {
        throw "Expected VNEditor.exe, received '$fullPath'"
    }

    return $fullPath
}

function Resolve-SdkSourcePath {
    param([Parameter(Mandatory)][string]$Path)

    $expandedPath = [Environment]::ExpandEnvironmentVariables($Path)
    $fullPath = [IO.Path]::GetFullPath($expandedPath)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Container)) {
        throw "SDK source directory does not exist: '$fullPath'"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $fullPath 'Engine') -PathType Container)) {
        throw "SDK source directory is missing the expected Engine subdirectory: '$fullPath'"
    }

    return $fullPath
}

function Get-GameRootFromEditor {
    param([Parameter(Mandatory)][string]$EditorPath)

    $win64Directory = Split-Path -Parent $EditorPath
    $binariesDirectory = Split-Path -Parent $win64Directory
    if ((Split-Path -Leaf $win64Directory) -ine 'Win64' -or
        (Split-Path -Leaf $binariesDirectory) -ine 'Binaries') {
        return $null
    }

    return [IO.Path]::GetFullPath((Split-Path -Parent $binariesDirectory))
}

function Get-UserGamePath {
    $documentsPath = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
    if ([string]::IsNullOrWhiteSpace($documentsPath)) {
        throw 'Windows did not report a My Documents directory for the current user.'
    }

    $userGameRoot = Join-Path $documentsPath 'My Games\Rising Storm 2\ROGame'
    return [pscustomobject]@{
        EditorIniPath      = Join-Path $userGameRoot 'Config\ROEditor.ini'
        CompiledScriptPath = Join-Path $userGameRoot 'Unpublished\CookedPC\Script\AircraftMod.u'
    }
}

function Test-ModPackageConfigured {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string[]]$Lines
    )

    $sectionName = ''
    foreach ($line in $Lines) {
        if ($line -match '^\s*\[(?<name>[^\]]+)\]') {
            $sectionName = $Matches['name'].Trim()
            continue
        }
        if ($line -match '^\s*[;#]' -or $sectionName -ine 'ModPackages') {
            continue
        }

        if ($line -match '^\s*\+?\s*ModPackages\s*=\s*(?<value>[^;#]*?)\s*(?:[;#].*)?$') {
            $packageName = $Matches['value'].Trim().Trim('"').Trim("'")
            if ($packageName -ieq 'AircraftMod') {
                return $true
            }
        }
    }

    return $false
}

function Assert-EditorPackageConfigured {
    param([Parameter(Mandatory)][string]$EditorIniPath)

    if (-not (Test-Path -LiteralPath $EditorIniPath -PathType Leaf)) {
        throw "Editor configuration was not found at '$EditorIniPath'. Launch RS2 or create the user config, then sync/build again."
    }

    $lines = Get-Content -LiteralPath $EditorIniPath
    if (-not (Test-ModPackageConfigured -Lines $lines)) {
        throw "Add 'ModPackages=AircraftMod' under '[ModPackages]' in '$EditorIniPath'. The build tool does not modify user configuration."
    }
}

function Resolve-Toolchain {
    param(
        [string]$EditorPath,
        [string]$SdkSourcePath
    )

    $installation = $null
    if ([string]::IsNullOrWhiteSpace($EditorPath)) {
        $installation = Find-RisingStorm2Install
        $EditorPath = $installation.EditorPath
    }

    $resolvedEditor = Resolve-EditorPath -Path $EditorPath
    $gameRoot = Get-GameRootFromEditor -EditorPath $resolvedEditor
    if ($null -eq $gameRoot -and $null -ne $installation) {
        $gameRoot = $installation.GameRoot
    }

    if ([string]::IsNullOrWhiteSpace($SdkSourcePath)) {
        if ([string]::IsNullOrWhiteSpace($gameRoot)) {
            throw 'Cannot derive Development\Src from this editor path. Supply --sdk-source-path to sync.'
        }
        $SdkSourcePath = Join-Path $gameRoot 'Development\Src'
    }

    $resolvedSdk = Resolve-SdkSourcePath -Path $SdkSourcePath
    $editorHash = (Get-FileHash -LiteralPath $resolvedEditor -Algorithm SHA256).Hash
    $editorFile = Get-Item -LiteralPath $resolvedEditor
    return [ordered]@{
        schemaVersion          = 4
        updatedAtUtc           = [DateTimeOffset]::UtcNow.ToString('O')
        steamAppId             = $script:SteamAppId
        gameRoot               = $gameRoot
        steamLibrary           = if ($null -ne $installation) { $installation.SteamLibrary } else { $null }
        editorPath             = $resolvedEditor
        editorSha256           = $editorHash
        editorLength           = $editorFile.Length
        editorLastWriteTimeUtc = $editorFile.LastWriteTimeUtc.ToString('O')
        sdkSourcePath          = $resolvedSdk
        consoleWrapperProtocol = $script:ConsoleWrapperProtocol
        consoleWrapperVersion  = $script:ConsoleWrapperVersion
    }
}

function Save-ToolchainCache {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Toolchain)

    $Toolchain['updatedAtUtc'] = [DateTimeOffset]::UtcNow.ToString('O')
    [void](New-Item -ItemType Directory -Path $script:BuildDirectory -Force)
    $temporaryPath = Join-Path $script:BuildDirectory (
        'toolchain.{0}.tmp' -f [guid]::NewGuid().ToString('N')
    )
    $json = ConvertTo-Json -InputObject $Toolchain -Depth 4
    $encoding = [Text.UTF8Encoding]::new($false)

    try {
        [IO.File]::WriteAllText($temporaryPath, $json, $encoding)
        if (Test-Path -LiteralPath $script:CachePath -PathType Leaf) {
            [IO.File]::Move($temporaryPath, $script:CachePath, $true)
        }
        else {
            [IO.File]::Move($temporaryPath, $script:CachePath)
        }
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}

function Get-CachedToolchain {
    if (-not (Test-Path -LiteralPath $script:CachePath -PathType Leaf)) {
        return $null
    }

    try {
        $cache = Get-Content -LiteralPath $script:CachePath -Raw | ConvertFrom-Json -AsHashtable
    }
    catch {
        throw "The toolchain cache at '$script:CachePath' is unreadable. Run sync to recreate it. $($_.Exception.Message)"
    }

    if ($cache.schemaVersion -ne 4) {
        throw 'The toolchain cache has an unsupported schema. Run sync to recreate it.'
    }
    if ($cache.consoleWrapperProtocol -ne $script:ConsoleWrapperProtocol -or
        $cache.consoleWrapperVersion -ne $script:ConsoleWrapperVersion) {
        throw 'The cached console wrapper metadata is unsupported. Run sync to recreate it.'
    }
    if (-not (Test-Path -LiteralPath $cache.editorPath -PathType Leaf)) {
        throw "The cached editor path is stale. Run sync. Cached path: '$($cache.editorPath)'"
    }
    if (-not (Test-Path -LiteralPath $cache.sdkSourcePath -PathType Container)) {
        throw "The cached SDK source path is stale. Run sync. Cached path: '$($cache.sdkSourcePath)'"
    }

    $currentHash = (Get-FileHash -LiteralPath $cache.editorPath -Algorithm SHA256).Hash
    if ($currentHash -ne $cache.editorSha256) {
        throw 'VNEditor.exe changed since the toolchain was synced. Run sync to refresh the editor identity.'
    }

    return $cache
}

function Get-ConsoleWrapperExecutable {
    $wrapperDirectory = Join-Path $script:BuildDirectory 'VNEditorConsoleWrapper'
    $wrapperPath = Join-Path $wrapperDirectory 'VNEditorConsoleWrapper.exe'
    if (-not (Test-Path -LiteralPath $wrapperPath -PathType Leaf)) {
        $projectPath = Join-Path $PSScriptRoot 'tools\build\VNEditorConsoleWrapper.csproj'
        throw "The console wrapper executable is missing at '$wrapperPath'. Build it separately with: dotnet build '$projectPath' --configuration Release --output '$wrapperDirectory'."
    }

    return [IO.Path]::GetFullPath($wrapperPath)
}

function Read-CommandOption {
    param([string[]]$Arguments)

    $options = [ordered]@{
        EditorPath    = $null
        SdkSourcePath = $null
        Release       = $false
        NoColor       = $false
        DryRun        = $false
        Verbose       = $false
    }

    for ($index = 0; $index -lt $Arguments.Count; $index++) {
        switch ($Arguments[$index]) {
            '--editor-path' {
                $index++
                if ($index -ge $Arguments.Count -or [string]::IsNullOrWhiteSpace($Arguments[$index])) {
                    throw '--editor-path requires a path.'
                }
                $options.EditorPath = $Arguments[$index]
            }
            '--sdk-source-path' {
                $index++
                if ($index -ge $Arguments.Count -or [string]::IsNullOrWhiteSpace($Arguments[$index])) {
                    throw '--sdk-source-path requires a path.'
                }
                $options.SdkSourcePath = $Arguments[$index]
            }
            '--release' {
                $options.Release = $true
            }
            '--no-color' {
                $options.NoColor = $true
            }
            '--dry-run' {
                $options.DryRun = $true
            }
            '--verbose' {
                $options.Verbose = $true
            }
            default {
                throw "Unknown option: $($Arguments[$index])"
            }
        }
    }

    return $options
}

function Invoke-EditorBuild {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Toolchain,
        [Parameter(Mandatory)][string]$OutputPath,
        [switch]$Release
    )

    if ([string]::IsNullOrWhiteSpace([string]$Toolchain.gameRoot)) {
        throw 'Cannot determine the RS2 game root from the cached editor path.'
    }

    $arguments = [System.Collections.Generic.List[string]]::new()
    $arguments.Add('make')
    $arguments.Add('-useunpublished')
    $arguments.Add('-FORCELOGFLUSH')
    if ($Release) {
        $arguments.Add('-stripsource')
    }

    $wrapperPath = Get-ConsoleWrapperExecutable
    $argumentsJson = ConvertTo-Json -InputObject ([string[]]$arguments.ToArray()) -Compress
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $wrapperPath
    $startInfo.WorkingDirectory = [string]$Toolchain.gameRoot
    $startInfo.UseShellExecute = $false
    $startInfo.ArgumentList.Add('--editor-path')
    $startInfo.ArgumentList.Add([string]$Toolchain.editorPath)
    $startInfo.ArgumentList.Add('--working-directory')
    $startInfo.ArgumentList.Add([string]$Toolchain.gameRoot)
    $startInfo.ArgumentList.Add('--arguments-json')
    $startInfo.ArgumentList.Add($argumentsJson)

    $binaryDirectory = Split-Path -Parent ([string]$Toolchain.editorPath)
    $pathVariable = $startInfo.Environment['PATH']
    if ([string]::IsNullOrWhiteSpace($pathVariable)) {
        $pathVariable = $env:PATH
    }
    $startInfo.Environment['PATH'] = "$binaryDirectory;$pathVariable"

    Write-BuildLog -Level info -Message (
        "Running '$($Toolchain.editorPath)' through '$wrapperPath' with arguments: '$($arguments -join ' ')'"
    )
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $process = [Diagnostics.Process]::Start($startInfo)
    if ($null -eq $process) {
        throw 'Windows did not start the VNEditor console wrapper.'
    }

    try {
        $process.WaitForExit()
        $exitCode = $process.ExitCode
    }
    finally {
        $process.Dispose()
    }
    $timer.Stop()

    if ($exitCode -ne 0) {
        throw "The VNEditor console wrapper or editor failed with exit code $exitCode after $($timer.Elapsed)."
    }
    if (-not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) {
        throw "VNEditor exited successfully but did not produce the expected script package: '$OutputPath'"
    }

    $output = Get-Item -LiteralPath $OutputPath
    if ($output.Length -eq 0) {
        throw "VNEditor produced an empty script package: '$OutputPath'"
    }

    Write-BuildLog -Level success -Message (
        "Build completed in $($timer.Elapsed). Output: '$($output.FullName)' ($($output.Length) bytes)"
    )
}

function Invoke-BuildTool {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$Command,
        [string[]]$CommandArguments
    )

    $command = $Command.ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($command)) {
        if ($CommandArguments.Count -gt 0) {
            throw 'Options require a command. Run .\build.ps1 help.'
        }
        Show-Usage
        return
    }

    if ($command -eq 'help') {
        if ($CommandArguments.Count -gt 0) {
            throw 'The help command does not accept options.'
        }
        Show-Help
        return
    }

    $options = Read-CommandOption -Arguments $CommandArguments
    if ($options.NoColor) {
        $script:NoColor = $true
    }
    if ($options.Verbose) {
        $VerbosePreference = 'Continue'
    }

    switch ($command) {
        'sync' {
            $toolchain = Resolve-Toolchain `
                -EditorPath $options.EditorPath `
                -SdkSourcePath $options.SdkSourcePath
            if ($options.DryRun) {
                Write-BuildLog -Level info -Message (
                    "Dry run: would write toolchain cache to '$script:CachePath'."
                )
            }
            elseif ($PSCmdlet.ShouldProcess($script:CachePath, 'Write toolchain cache')) {
                Save-ToolchainCache -Toolchain $toolchain
                Write-BuildLog -Level success -Message 'Toolchain paths cached.'
            }
            Write-BuildLog -Level info -Message "Editor: '$($toolchain.editorPath)'"
            Write-BuildLog -Level info -Message "SDK sources: '$($toolchain.sdkSourcePath)'"
            Write-BuildLog -Level info -Message "Cache: '$script:CachePath'"
            return
        }
        'build' {
            if ($null -ne $options.EditorPath -or $null -ne $options.SdkSourcePath) {
                throw 'Path overrides are accepted by sync. Run sync with the desired paths, then build.'
            }

            if (Test-Path -LiteralPath $script:CachePath -PathType Leaf) {
                $toolchain = Get-CachedToolchain
            }
            else {
                Write-BuildLog -Level info -Message 'No cache found. Locating the RS2 toolchain.'
                $toolchain = Resolve-Toolchain
                if ($options.DryRun) {
                    Write-BuildLog -Level info -Message (
                        "Dry run: would write toolchain cache to '$script:CachePath'."
                    )
                }
                elseif ($PSCmdlet.ShouldProcess($script:CachePath, 'Write toolchain cache')) {
                    Save-ToolchainCache -Toolchain $toolchain
                }
            }

            $userPaths = Get-UserGamePath
            Assert-EditorPackageConfigured -EditorIniPath $userPaths.EditorIniPath
            Write-BuildLog -Level info -Message "Editor config: '$($userPaths.EditorIniPath)'"
            Write-BuildLog -Level info -Message "Expected script output: '$($userPaths.CompiledScriptPath)'"
            Write-BuildLog -Level info -Message "Editor: '$($toolchain.editorPath)'"
            Write-Verbose -Message "Editor SHA-256: $($toolchain.editorSha256)"

            if ($options.DryRun) {
                Write-BuildLog -Level info -Message (
                    "Dry run: would run UnrealScript compilation with '$($toolchain.editorPath)'."
                )
            }
            elseif ($PSCmdlet.ShouldProcess($toolchain.editorPath, 'Run UnrealScript compilation')) {
                Invoke-EditorBuild `
                    -Toolchain $toolchain `
                    -OutputPath $userPaths.CompiledScriptPath `
                    -Release:$options.Release
            }
        }
        default {
            throw "Unknown command '$Command'. Run .\build.ps1 help."
        }
    }
}

try {
    $invokeParameters = @{
        Command          = $Command
        CommandArguments = $CommandArguments
    }
    foreach ($commonParameter in @('Verbose', 'WhatIf', 'Confirm')) {
        if ($PSBoundParameters.ContainsKey($commonParameter)) {
            $invokeParameters[$commonParameter] = $PSBoundParameters[$commonParameter]
        }
    }

    Invoke-BuildTool @invokeParameters
}
catch {
    Write-BuildLog -Level error -Message $_.Exception.Message
    exit 1
}
