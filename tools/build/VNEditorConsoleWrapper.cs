// Copyright (c) 2026 Tuomo Kriikkula
//
// MIT License
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

using System.ComponentModel;
using System.Diagnostics;
using System.Globalization;
using System.IO.Pipes;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using System.Text;
using System.Text.Json;
using Microsoft.Win32.SafeHandles;

namespace AircraftMod.Build;

internal static class Program
{
    private static async Task<int> Main(string[] args)
    {
        if (args is not
            [
                "--editor-path",
                var editorPath,
                "--working-directory",
                var workingDirectory,
                "--arguments-json",
                var argumentsJson
            ])
        {
            Console.Error.WriteLine(
                "Usage: VNEditorConsoleWrapper --editor-path <path> " +
                "--working-directory <path> --arguments-json <json-array>");
            return 2;
        }

        if (!OperatingSystem.IsWindows())
        {
            Console.Error.WriteLine("The VNEditor output wrapper requires Windows.");
            return 2;
        }

        try
        {
            string[] editorArguments = JsonSerializer.Deserialize<string[]>(argumentsJson)
                ?? throw new JsonException("The editor arguments must be a JSON string array.");
            if (editorArguments.Any(static argument => argument is null))
            {
                throw new JsonException("Editor arguments cannot contain null values.");
            }

            return await DualModeLauncher
                .RunAsync(editorPath, workingDirectory, editorArguments)
                .ConfigureAwait(false);
        }
        catch (Exception exception) when (
            exception is ArgumentException or
                IOException or
                InvalidOperationException or
                JsonException or
                PlatformNotSupportedException or
                UnauthorizedAccessException or
                Win32Exception)
        {
            Console.Error.WriteLine($"VNEditor output wrapper failed: {exception.Message}");
            return 1;
        }
    }
}

[SupportedOSPlatform("windows")]
internal static class DualModeLauncher
{
    private const uint CreateSuspended = 0x00000004;
    private static readonly ConsoleColor[] ColorPalette =
    [
        ConsoleColor.Black,
        ConsoleColor.Black,
        ConsoleColor.DarkBlue,
        ConsoleColor.Blue,
        ConsoleColor.DarkGreen,
        ConsoleColor.Green,
        ConsoleColor.DarkCyan,
        ConsoleColor.Cyan,
        ConsoleColor.DarkRed,
        ConsoleColor.Red,
        ConsoleColor.DarkMagenta,
        ConsoleColor.Magenta,
        ConsoleColor.DarkYellow,
        ConsoleColor.Yellow,
        ConsoleColor.Gray,
        ConsoleColor.White
    ];

    public static async Task<int> RunAsync(
        string applicationPath,
        string workingDirectory,
        string[] arguments)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(applicationPath);
        ArgumentException.ThrowIfNullOrWhiteSpace(workingDirectory);
        ArgumentNullException.ThrowIfNull(arguments);

        var started = StartSuspended(applicationPath, workingDirectory, arguments);
        using var nativeProcess = started.Process;
        using var nativeThread = started.Thread;

        Process? process = null;
        Task? processExit = null;
        Task? pipeConnection = null;
        CancellationTokenSource? connectionCancellation = null;
        var resumed = false;

        try
        {
            process = Process.GetProcessById(checked((int)started.ProcessId));
            await using var pipe = new NamedPipeServerStream(
                started.ProcessId.ToString(CultureInfo.InvariantCulture) + "cout",
                PipeDirection.In,
                maxNumberOfServerInstances: 1,
                PipeTransmissionMode.Byte,
                PipeOptions.Asynchronous | PipeOptions.CurrentUserOnly,
                inBufferSize: 1024,
                outBufferSize: 1024);
            using var outputClosedEvent = new EventWaitHandle(
                initialState: false,
                EventResetMode.AutoReset,
                "dualmode_die_event" + started.ProcessId.ToString(CultureInfo.InvariantCulture));
            _ = outputClosedEvent;

            connectionCancellation = new CancellationTokenSource();
            pipeConnection = pipe.WaitForConnectionAsync(connectionCancellation.Token);
            processExit = process.WaitForExitAsync();

            uint previousSuspendCount = NativeMethods.ResumeThread(nativeThread.DangerousGetHandle());
            if (previousSuspendCount == uint.MaxValue)
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Failed to resume VNEditor.");
            }
            resumed = true;
            nativeThread.Dispose();

            Task firstCompleted = await Task.WhenAny(pipeConnection, processExit).ConfigureAwait(false);
            if (firstCompleted == processExit && !pipe.IsConnected && !pipeConnection.IsCompleted)
            {
                connectionCancellation.Cancel();
                try
                {
                    await pipeConnection.ConfigureAwait(false);
                }
                catch (OperationCanceledException) when (connectionCancellation.IsCancellationRequested)
                {
                }

                await processExit.ConfigureAwait(false);
                if (process.ExitCode == 0)
                {
                    throw new InvalidOperationException(
                        "VNEditor exited without connecting to its dual-mode output pipe.");
                }

                return process.ExitCode;
            }

            await pipeConnection.ConfigureAwait(false);
            Task output = ForwardOutputAsync(pipe);
            await Task.WhenAll(output, processExit).ConfigureAwait(false);
            return process.ExitCode;
        }
        catch (Exception operationError)
        {
            connectionCancellation?.Cancel();
            await ObservePendingConnectionAsync(pipeConnection).ConfigureAwait(false);
            try
            {
                await StopProcessAsync(process, nativeProcess, resumed, processExit).ConfigureAwait(false);
            }
            catch (Exception cleanupError)
            {
                throw new AggregateException(
                    "VNEditor failed and the wrapper could not stop it cleanly.",
                    operationError,
                    cleanupError);
            }

            throw;
        }
        finally
        {
            connectionCancellation?.Dispose();
            process?.Dispose();
        }
    }

    private static unsafe StartedProcessHandles StartSuspended(
        string applicationPath,
        string workingDirectory,
        string[] arguments)
    {
        string commandLine = BuildCommandLine(applicationPath, arguments);
        char[] commandLineBuffer = [.. commandLine, '\0'];
        var startupInfo = new NativeMethods.StartupInfo
        {
            Size = checked((uint)Marshal.SizeOf<NativeMethods.StartupInfo>())
        };
        NativeMethods.ProcessInformation processInformation;

        fixed (char* commandLinePointer = commandLineBuffer)
        {
            bool started = NativeMethods.CreateProcess(
                applicationPath,
                commandLinePointer,
                nint.Zero,
                nint.Zero,
                inheritHandles: false,
                CreateSuspended,
                nint.Zero,
                workingDirectory,
                ref startupInfo,
                out processInformation);
            if (!started)
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Failed to start VNEditor.");
            }
        }

        return new StartedProcessHandles(
            new SafeProcessHandle(processInformation.Process, ownsHandle: true),
            new SafeWaitHandle(processInformation.Thread, ownsHandle: true),
            processInformation.ProcessId);
    }

    private static string BuildCommandLine(string applicationPath, IEnumerable<string> arguments)
    {
        var commandLine = new StringBuilder(QuoteArgument(applicationPath));
        foreach (string argument in arguments)
        {
            commandLine.Append(' ').Append(QuoteArgument(argument));
        }

        return commandLine.ToString();
    }

    private static string QuoteArgument(string argument)
    {
        if (argument.Length > 0 && argument.IndexOfAny([' ', '\t', '\n', '\v', '"']) < 0)
        {
            return argument;
        }

        var quoted = new StringBuilder().Append('"');
        int backslashCount = 0;
        foreach (char character in argument)
        {
            if (character == '\\')
            {
                backslashCount++;
                continue;
            }

            if (character == '"')
            {
                quoted.Append('\\', (backslashCount * 2) + 1).Append('"');
                backslashCount = 0;
                continue;
            }

            quoted.Append('\\', backslashCount).Append(character);
            backslashCount = 0;
        }

        quoted.Append('\\', backslashCount * 2).Append('"');
        return quoted.ToString();
    }

    private static async Task ForwardOutputAsync(Stream pipe)
    {
        var decoder = new DualModeOutputDecoder();
        using var reader = new StreamReader(pipe, Encoding.Unicode, detectEncodingFromByteOrderMarks: false);
        char[] buffer = new char[512];
        int charactersRead;
        while ((charactersRead = await reader.ReadAsync(buffer).ConfigureAwait(false)) > 0)
        {
            decoder.Append(buffer.AsSpan(0, charactersRead));
            Console.Out.Flush();
        }

        decoder.Flush();
        if (!Console.IsOutputRedirected)
        {
            Console.ResetColor();
        }
        Console.Out.Flush();
    }

    private static async Task ObservePendingConnectionAsync(Task? connection)
    {
        if (connection is null || connection.IsCompleted)
        {
            return;
        }

        try
        {
            await connection.ConfigureAwait(false);
        }
        catch (OperationCanceledException)
        {
        }
        catch (IOException)
        {
        }
        catch (ObjectDisposedException)
        {
        }
    }

    private static async Task StopProcessAsync(
        Process? process,
        SafeProcessHandle nativeProcess,
        bool resumed,
        Task? processExit)
    {
        if (process is null)
        {
            if (!NativeMethods.TerminateProcess(nativeProcess.DangerousGetHandle(), exitCode: 1))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Failed to terminate suspended VNEditor.");
            }

            return;
        }

        try
        {
            if (resumed)
            {
                process.Kill(entireProcessTree: true);
            }
            else if (!NativeMethods.TerminateProcess(nativeProcess.DangerousGetHandle(), exitCode: 1))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Failed to terminate suspended VNEditor.");
            }
        }
        catch (InvalidOperationException) when (processExit?.IsCompleted is true)
        {
        }
        catch (Win32Exception) when (processExit?.IsCompleted is true)
        {
        }

        await process.WaitForExitAsync().ConfigureAwait(false);
    }

    private readonly record struct StartedProcess(
        SafeProcessHandle Process,
        SafeWaitHandle Thread,
        uint ProcessId);

    private sealed class DualModeOutputDecoder
    {
        private const string ColorMarker = "\u0060~[~\u0060";
        private readonly StringBuilder _pending = new();

        public void Append(ReadOnlySpan<char> characters)
        {
            _pending.Append(characters);
            ProcessPending(final: false);
        }

        public void Flush() => ProcessPending(final: true);

        private void ProcessPending(bool final)
        {
            string text = _pending.ToString();
            int position = 0;
            while (position < text.Length)
            {
                int markerIndex = text.IndexOf(ColorMarker, position, StringComparison.Ordinal);
                if (markerIndex < 0)
                {
                    int safeLength = final
                        ? text.Length - position
                        : Math.Max(0, text.Length - position - ColorMarker.Length + 1);
                    WriteText(text.AsSpan(position, safeLength));
                    position += safeLength;
                    break;
                }

                WriteText(text.AsSpan(position, markerIndex - position));
                int commandStart = markerIndex + ColorMarker.Length;
                int remaining = text.Length - commandStart;
                string commandPrefix = text.Substring(commandStart, Math.Min(5, remaining));
                if (commandPrefix.StartsWith("Reset", StringComparison.Ordinal))
                {
                    if (!Console.IsOutputRedirected)
                    {
                        Console.ResetColor();
                    }
                    position = commandStart + 5;
                    continue;
                }
                if (remaining < 4 ||
                    (!final && "Reset".StartsWith(commandPrefix, StringComparison.Ordinal)))
                {
                    if (final)
                    {
                        WriteText(text.AsSpan(markerIndex));
                        position = text.Length;
                    }
                    else
                    {
                        position = markerIndex;
                    }

                    break;
                }

                ReadOnlySpan<char> colorValue = text.AsSpan(commandStart, 4);
                if (Int32.TryParse(
                        colorValue,
                        NumberStyles.HexNumber,
                        CultureInfo.InvariantCulture,
                        out int colorIndex) &&
                    (uint)colorIndex < (uint)ColorPalette.Length)
                {
                    if (!Console.IsOutputRedirected)
                    {
                        Console.ForegroundColor = ColorPalette[colorIndex];
                    }
                    position = commandStart + 4;
                    continue;
                }

                WriteText(ColorMarker.AsSpan());
                position = commandStart;
            }

            _pending.Clear();
            if (position < text.Length)
            {
                _pending.Append(text.AsSpan(position));
            }
        }

        private static void WriteText(ReadOnlySpan<char> text)
        {
            if (!text.IsEmpty)
            {
                Console.Out.Write(text);
            }
        }
    }
}

internal readonly record struct StartedProcessHandles(
    SafeProcessHandle Process,
    SafeWaitHandle Thread,
    uint ProcessId);

internal static partial class NativeMethods
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    internal struct StartupInfo
    {
        public uint Size;
        public nint Reserved;
        public nint Desktop;
        public nint Title;
        public uint X;
        public uint Y;
        public uint XSize;
        public uint YSize;
        public uint XCountChars;
        public uint YCountChars;
        public uint FillAttribute;
        public uint Flags;
        public ushort ShowWindow;
        public ushort Reserved2Size;
        public nint Reserved2;
        public nint StandardInput;
        public nint StandardOutput;
        public nint StandardError;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct ProcessInformation
    {
        public nint Process;
        public nint Thread;
        public uint ProcessId;
        public uint ThreadId;
    }

    [LibraryImport(
        "kernel32.dll",
        EntryPoint = "CreateProcessW",
        StringMarshalling = StringMarshalling.Utf16,
        SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static unsafe partial bool CreateProcess(
        string applicationName,
        char* commandLine,
        nint processAttributes,
        nint threadAttributes,
        [MarshalAs(UnmanagedType.Bool)] bool inheritHandles,
        uint creationFlags,
        nint environment,
        string currentDirectory,
        ref StartupInfo startupInfo,
        out ProcessInformation processInformation);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    internal static partial uint ResumeThread(nint thread);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static partial bool TerminateProcess(nint process, uint exitCode);
}
