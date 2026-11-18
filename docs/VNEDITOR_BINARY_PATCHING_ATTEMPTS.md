# VNEditor binary-patching attempts

## Outcome

No binary patch was verified as a working solution. The build now uses the
unmodified editor through the [dual-mode console wrapper](../tools/build/README.md).
The original `VNEditor.exe` remained unchanged.

This document records the experiments and the limits of their evidence. It is
not a patch recipe and does not recommend applying either candidate patch.

## Source executable

The inspected file was `Binaries\Win64\VNEditor.exe` under the installed
Rising Storm 2 game directory. The drive letter and Steam library path vary by
machine and are intentionally omitted here.

| Property | Value |
|---|---|
| SHA-256 | `53C7BCAB5765F780443E7503AAFD7E34FA53429FD19B76B066B3397A7CE40D5C` |
| Length | 57,972,224 bytes |
| PE machine | x64 (`0x8664`) |
| Optional header | PE32+ (`0x20B`) |
| Image base | `0x140000000` |
| Subsystem | Windows GUI (`2`) |

The patch prototype checked the source hash and expected bytes before writing
to a sibling copy. It never wrote to the original executable.

## Attempt 1: change only the PE subsystem

The first sibling copy changed the PE optional-header `Subsystem` WORD at raw
file offset `0x214` from `02 00` (GUI) to `03 00` (console). A byte-for-byte
comparison confirmed this was its only changed file offset; the copy retained
the original length.

The copy created on the research machine was:

| Property | Value |
|---|---|
| Relative path | `Binaries\Win64\VNEditor.Console-53C7BCAB5765.exe` (beside `VNEditor.exe`) |
| SHA-256 | `14F565B54B6450BD71BDA55074817300A96BF7E4BA459FA66B647EAAF2545586` |
| Observed `LastWriteTimeUtc` | `2026-11-17T22:51:58.3119022Z` |
| Length | 57,972,224 bytes |
| Changed offset | `0x214`: `02` to `03` |

This generated copy remains beside the editor on the research machine, but
`build.ps1` no longer uses it and it is not tracked in Git. Its recorded
`LastWriteTimeUtc` is file metadata, not an independently preserved patch
timestamp. The local schema-3 cache that once held patch metadata was replaced
by the current schema-4 wrapper cache.

The intended effect was to have Windows treat the copy as a console-subsystem
program. This changes how Windows establishes console attachment; it does not
create a pipe server, forward VNEditor's output, or make a child process
synchronous by itself.

The only recorded invocation of this copy used
`-make -useunpublished`. That spelling was later corrected to
`make -useunpublished`. The user observed an outdated-scripts dialog for the
incorrect invocation. Because the command was wrong, this was not a valid test
of the compiler path, and it neither proves nor disproves the subsystem
change's behavior with the correct command. The experiment did not verify the
required combination of terminal output, no extra console window, and
synchronous completion.

## Attempt 2: proposed hash-guarded v2 patch

A later, unexecuted recipe was added temporarily to the PowerShell prototype.
It expected the source SHA-256 shown above and proposed three changes:

The prototype labeled the recipe version `2` and recorded its type as
`pe-subsystem-console+steam-restart-bypass+auto-yes-outdated-scripts`.

| Change | Address / file offset | Original bytes | Candidate bytes | Rationale and evidence |
|---|---|---|---|---|
| GUI-to-console subsystem | File offset `0x214` | `02 00` | `03 00` | Same unverified subsystem-only change as attempt 1. |
| Bypass Steam restart call | VA `0x141313879`, RVA `0x1313879`, file offset `0x1312C79` | `FF 15 91 A7 DC 00` | `31 C0 90 90 90 90` | Ghidra identified the indirect call as `SteamAPI_RestartAppIfNecessary`. The replacement would zero `EAX` and skip the remaining call bytes, forcing a false-like result. The call's relevance to the correct `make` path was not established. |
| Bypass outdated-scripts prompt call | VA `0x1413AEC44`, RVA `0x13AEC44`, file offset `0x13AE044` | `E8 77 0F D5 FE` | `31 C0 90 90 90` | Ghidra placed the call in the startup/dialog path; the target was `FUN_1400ffbc0`, the Yes/No/Cancel dialog helper. The prototype assumed returning zero would accept the rebuild prompt, but the return-code semantics were not proven. |

The byte signatures and source hash passed a `-WhatIf` dry run. That only
validated that the recipe matched the inspected binary; it did not create or
run a v2 executable. No `VNEditor.Console-v2-...exe` was produced.

The dialog replacement was especially risky: skipping a dialog function and
forcing `EAX` to zero is not evidence that the caller interprets zero as “Yes.”
It could select another result or bypass required side effects. The Steam
restart bypass was also unnecessary unless the correct build invocation
actually reached that restart path. Neither code patch was tested with
`make -useunpublished`.

## Why the wrapper replaced these attempts

Ghidra analysis found that VNEditor already opens a PID-specific
`\\.\pipe\{pid}cout` during startup, assigns it to `STD_OUTPUT_HANDLE`, and
signals `dualmode_die_event{pid}` when closing the pipe. UDK.com's companion
launcher uses the same protocol, although its one-millisecond
`HasExited`/event loop polls and was not copied.

The C# wrapper creates the named pipe and event before resuming the suspended
editor process, reads the pipe asynchronously, and waits for both pipe closure
and process exit. This directly addresses output capture and completion
without changing editor bytes. The correct `make -useunpublished
-FORCELOGFLUSH` command was then run through the wrapper and compiled
`AircraftMod.u` successfully. The original editor hash was rechecked and
remained unchanged.

`-FORCELOGFLUSH` is a real VNEditor flag that flushes log entries; it is not a
binary patch and is not used to detect completion. The earlier `-unattended`
idea was also not used because the inspected prompt path appeared to return a
cancel result in unattended mode.
