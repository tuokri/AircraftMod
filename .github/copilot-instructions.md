# Copilot instructions

## Build, test, and lint

The UnrealScript toolchain helper is `build.ps1`:

```powershell
.\build.ps1 help
.\build.ps1 sync
.\build.ps1 build
.\build.ps1 build --release
```

`sync` discovers the installed RS2 editor and `Development\Src` through Steam,
then caches their absolute paths in the gitignored `.build\toolchain.json`.
Inspect the cached SDK source directory for engine/API context. `build` invokes
the original editor with `make -useunpublished -FORCELOGFLUSH`;
`--release` adds `-stripsource`. `-FORCELOGFLUSH` flushes each log entry but is
not used to detect build completion. Before compiling, the tool checks for
`ModPackages=AircraftMod` under `[ModPackages]` in `ROEditor.ini`, resolved
from the current user's My Documents directory. The expected script output is
`Documents\My Games\Rising Storm 2\ROGame\Unpublished\CookedPC\Script\AircraftMod.u`.

The PowerShell entry point owns toolchain discovery, cache/config validation,
build arguments, and output verification. The .NET 10 console wrapper in
`tools\build` only handles VNEditor's built-in PID-specific dual-mode named
pipe: it starts the editor suspended, creates the pipe and matching event,
then forwards UTF-16 output asynchronously while waiting for pipe closure and
process exit. It does not patch or replace `VNEditor.exe`, and it does not poll
logs or process status. Build the helper separately before running `build.ps1`:

```powershell
dotnet build .\tools\build\VNEditorConsoleWrapper.csproj --configuration Release --output .\.build\VNEditorConsoleWrapper
```

`build.ps1` only builds UnrealScript code and never runs `dotnet build`.

For PowerShell changes, run `Invoke-ScriptAnalyzer -Path .\build.ps1` and format
with PSScriptAnalyzer's `Invoke-Formatter`.
Keep all `Write-BuildLog` messages free of semicolons and em dashes.
Enclose every file or directory path in a `Write-BuildLog` message in single
quotes.

For C# wrapper changes, build `tools\build\VNEditorConsoleWrapper.csproj` with
the .NET 10 SDK and run `dotnet format` on that project. Keep the helper's
`.gitignore` in `tools\build`; do not commit generated binaries. Mod cooking is
separate future work; no `cook` command exists yet.

See `tools\build\README.md` for the wrapper protocol and
`docs\VNEDITOR_BINARY_PATCHING_ATTEMPTS.md` for historical patch experiments.

The Python viewer is an isolated project. Run its commands from `tools\flight_trace_viewer`:

```powershell
uv build
uv run pytest
uv run pytest tests\test_presentation.py::test_identity_pose_preserves_demo_axes
uv run ruff check
uv run ruff format --check
uv run ty check
```

The Plotly renderer is optional. To exercise it, use `uv run --extra plotly pytest tests\test_plotly_renderer.py`; launch it with `uv run --extra plotly flight_trace_viewer_plotly`. The Matplotlib demo runs with `uv run flight_trace_viewer`.

## Architecture

- `AMMutator` installs `AMPlayerController`; the controller contains the development spawn/debug commands. `AMHUD` customizes the inherited helicopter instruments. `AMVehicleFactory_O1BirdDog` points the game factory at the concrete Bird Dog content class.
- `AMVehicleAircraft` is the shared aircraft/flight-physics layer over `ROVehicleHelicopter`. It gathers forces from the configured `AeroSurfaceComponents`; each `AeroSurfaceComponent` calculates its surface lift, drag, and aerodynamic torque, and the vehicle aggregates these about the center of mass before submitting force, torque, and thrust to UE3 physics.
- `AMAircraft_O1BirdDog` contains aircraft behavior; `AMAircraft_O1BirdDog_Content` supplies mesh/assets, sockets, and component configuration. The explicit `AeroSurfaceComponents` array is the active force/control inventory: it currently lists the two elevators and two wings. A declared component such as the rudder does not participate unless it is added to this array.
- `AMFlightCsvLogger` is only a scaffold (`StartSession` currently returns `false`), and `tools\flight_trace_viewer` currently displays generated synthetic data rather than loading UE3 CSVs. Do not treat them as a working telemetry-to-viewer pipeline.

## Repository-specific conventions

- UnrealScript actor/component setup and aircraft-specific tuning live in `DefaultProperties`; preserve the distinction between declaring a component, attaching it to a mesh/socket, and adding it to the active surface array.
- In the aircraft tick, force calculation runs before `HandleInputs`. This means newly sampled controls are applied after that tick's force pass; preserve the order unless intentionally changing control timing.
- Aerodynamic calculations depend on component-local axes, cross-product order, and UE3 units. The current surface calculation projects local airflow by zeroing Y, while the viewer's synthetic display basis is X-forward/Y-right/Z-up and is not a verified UE3 conversion. Verify socket orientation, units, and the current physics API before changing axes or adding conversions; consult `docs\FLIGHT_MODEL_IMPLEMENTATION_PLAN.md` for test rationale, but verify its findings against current code.
- Use the logging macros in `AMMacros.uci` for AircraftMod-tagged messages. When changing code adapted from the Unity aircraft-physics project, retain the applicable notice and consult `ThirdPartyLicenses\LICENSE-Aircraft-Physics`.
- Keep Python tooling in the viewer subproject. Its Ruff configuration sets a 100-character line length and single-line imports; its tests are under `tests`. Plotly is an optional dependency, separate from the Matplotlib demo.

## Copyright notices

Include the MIT license header in new code implementation files such as `.uc`,
`.py`, `.ps1`, and `.cs`. Do not add license headers to metadata or configuration
files such as `.gitignore` or `.csproj`.

## Commit messages

Use Conventional Commits for all new commits, in the form
`<type>[optional scope]: <description>`. Mark breaking changes with `!` and a
`BREAKING CHANGE:` footer. See
https://www.conventionalcommits.org/en/v1.0.0-beta.2/.
