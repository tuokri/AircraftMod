# VNEditor dual-mode console wrapper

## Purpose

`VNEditorConsoleWrapper` is a small .NET console program that lets the
PowerShell `build.ps1` entry point capture UnrealScript compiler output from
the unmodified Rising Storm 2 `VNEditor.exe` and wait for the editor to finish.
It is a process/output adapter only: Steam discovery, the user `ROEditor.ini`
preflight, compiler arguments, and `.u` output validation remain in
`build.ps1`.

The wrapper does not patch, rename, or replace `VNEditor.exe`. It relies on
VNEditor's existing PID-specific named-pipe output path.

## Build and use

The helper targets .NET 10 and C# 14. It is framework-dependent, so the .NET 10
runtime is also required to run its executable. Build it separately from the
repository root:

```powershell
dotnet build .\tools\build\VNEditorConsoleWrapper.csproj --configuration Release --output .\.build\VNEditorConsoleWrapper
```

The resulting `.build\VNEditorConsoleWrapper\VNEditorConsoleWrapper.exe` is
gitignored. `build.ps1` expects this prebuilt executable and does not invoke
`dotnet build`. The helper binary may be distributed from GitHub in the future;
downloading or updating it is not implemented yet.

The helper's command-line contract is:

```text
VNEditorConsoleWrapper --editor-path <path> --working-directory <path> --arguments-json <json-array>
```

`build.ps1` supplies the original editor path, the RS2 game root, and a JSON
array such as `["make","-useunpublished","-FORCELOGFLUSH"]`. JSON keeps the
individual arguments unambiguous; the helper then quotes them using Windows
command-line rules before calling `CreateProcessW`. It also passes the game
root as the editor's working directory and prepends `Binaries\Win64` to the
inherited `PATH` for editor dependencies.

## VNEditor's output protocol

Static inspection in Ghidra was performed against this exact editor:

- SHA-256: `53C7BCAB5765F780443E7503AAFD7E34FA53429FD19B76B066B3397A7CE40D5C`
- PE: x64, PE32+, image base `0x140000000`
- PE subsystem: Windows GUI (`2`)

The relevant function names below are Ghidra-generated labels, not symbols
provided by the executable.

During startup, `FUN_1413ae100` calls `FUN_1400e1570`. That function:

1. Calls `GetCurrentProcessId`.
2. Formats the pipe name `\\.\pipe\{pid}cout`, with the PID in decimal.
3. Opens the existing pipe with `CreateFileW` for `GENERIC_WRITE`.
4. Assigns the resulting handle to `STD_OUTPUT_HANDLE` with `SetStdHandle`.

The editor does not require a `-dualmode` argument. Its output is raw UTF-16LE
text on a byte-mode pipe. The matching close routine, `FUN_1400e2650`, formats
`dualmode_die_event{pid}`, opens the event for modification, signals it, and
closes the pipe handle.

The external UDK 2015 `UDK.com` launcher at
`UDK-2015-01\Binaries\Win64\UDK.com` was inspected as a protocol reference;
`UDK-2015-01\Binaries\Win64\UDK.exe` also contains the matching pipe/event
strings. These external files are not part of this repository. UDK.com's
`NamedPipe.Connect` creates an inbound, byte-mode pipe with one instance and
1024-byte buffers, then calls `ConnectNamedPipe`. Its reader interprets each
two-byte pair as a UTF-16 code unit. `Program.Main` also creates an auto-reset
`dualmode_die_event{pid}` event. The direct behavioral evidence for Rising
Storm 2 comes from VNEditor's own code and the real build, not from the UDK
string matches alone.

UDK.com's output loop calls `ReadFile`, checks `Process.HasExited`, and waits
on the event with a one-millisecond timeout before repeating. That is polling;
this helper deliberately does not copy that loop.

## Launch and wait sequence

The pipe name contains the child PID, so the server must exist before VNEditor
tries to open it. The wrapper avoids a startup race by:

1. Building a correctly quoted Unicode command line.
2. Calling `CreateProcessW` with `CREATE_SUSPENDED` (`0x00000004`) to obtain the
   editor PID without letting its startup code run yet. The call inherits the
   wrapper's environment but does not inherit handles; VNEditor opens its pipe
   by name.
3. Creating an asynchronous, current-user-only inbound pipe named
   `{pid}cout`, plus the matching auto-reset event.
4. Starting `WaitForConnectionAsync` and `Process.WaitForExitAsync`.
5. Calling `ResumeThread` so VNEditor can connect to the already-existing pipe.
6. Reading the pipe asynchronously as UTF-16LE and forwarding text to the
   wrapper's inherited standard output.
7. Waiting for both pipe EOF and process exit, then returning VNEditor's exit
   code.

The named event is created so VNEditor's normal close notification can find
it, but completion does not depend on polling or waiting on that event. Pipe
EOF and the OS process wait are the completion signals. If startup fails after
the process was resumed, the wrapper stops the process tree and reports the
failure instead of returning success-shaped output. If VNEditor exits without
connecting, a nonzero exit code is propagated; a zero exit without a pipe is
reported as a protocol error.

VNEditor also writes short color-control records using the marker
`` `~[~` `` followed by `Reset` or four hexadecimal characters. The wrapper
handles markers split across read buffers, applies valid indices 0 through 15
using the UDK.com palette (black, black, dark blue, blue, dark green, green,
dark cyan, cyan, dark red, red, dark magenta, magenta, dark yellow, yellow,
gray, white), and consumes out-of-range codes without printing them. RS2 output
included the code `1111`, which is not a palette index, so it is consumed
without changing the color. `Reset` restores the console default. Ordinary text
is flushed promptly; color records are not treated as build progress or
completion.

## Why this works

The key is the executable's existing pipe client, not a PE subsystem change.
Creating the server while the process is suspended guarantees VNEditor's
`CreateFileW` call can succeed. The pipe carries the output that would
otherwise appear in the separately opened compiler console. The asynchronous
read keeps that output flowing, while `WaitForExitAsync` keeps the invoking
build process in control until the editor exits. Waiting for both EOF and
process exit avoids treating a closed output stream alone as proof that the
build process has finished.

This design leaves the GUI-subsystem editor unchanged and does not depend on
log-file freshness. `-FORCELOGFLUSH` is still passed to VNEditor because it is a
real engine flag that flushes each log entry, but it is not used as a wait
mechanism.

## Verification and limits

The wrapper was first exercised with a fake pipe client that emitted text,
closed its pipe before exiting, delayed its exit, and returned code `7`. The
wrapper forwarded the text, waited past pipe closure, and propagated the exit
code.

It was then used for a real `make -useunpublished -FORCELOGFLUSH` build. The
full compile produced the expected `AircraftMod.u`; a subsequent invocation
reported that no scripts needed recompiling. The original editor hash remained
unchanged and no VNEditor process remained after the wrapper returned.

These observations apply to the editor hash listed above. Revalidate the pipe
name, encoding, event behavior, and process lifetime after an editor update.
The helper does not implement dialog automation, does not patch other editor
versions, and does not download its executable.

## Development TODOs

- Clean up this readme!
- Check if the wrapper tool can use more modern and idiomatic C#
  while keeping the identical functionality!
