# Aircraft Flight Model Debugging and Implementation Plan

## Goal

Instrument the UE3 aircraft at the point where it calculates and submits physics forces, use a short repeatable flight to establish what is wrong, then correct the highest-confidence math and configuration issues one at a time. Do not tune coefficients to compensate for a coordinate-frame or unit error.

The plan assumes the existing UnrealScript `Tick()` is the available update hook. It is a game-frame trace, not a physics-solver trace.

## Verified baseline

The findings below were checked against AircraftMod `2b8c1ab272fd1a3ba6d614d9e858fba70babd9f1` and the Unity reference `141f2523cccbe24422cb9532420d28f50b84fbe2`.

| Finding | Verification and consequence |
|---|---|
| **Lift direction uses the wrong axis (high-confidence defect).** | `AeroSurfaceComponent.CalculateForces` transforms airflow into the component frame, zeros local Y, and transforms the remaining local X-Z vector back to world space (`Classes/AeroSurfaceComponent.uc`, around lines 151–156). It then crosses that direction with the component forward vector. Those vectors lie in the X-Z section plane, so their cross product points along the component's Y/span axis, not in the airfoil section plane. The Unity reference projects into X-Y and crosses with its local Z/forward axis (`AeroSurface.cs`, around lines 50–53), so that formula cannot be copied unchanged after changing the projected plane. |
| **`DeltaTime` is multiplied into aerodynamic force and torque before physics submission (confirmed code; likely design bug, impact needs runtime verification).** | `CalculateLiftTorqueThrust` calculates `DeltaTime * ForceThisFrame` and `DeltaTime * TorqueThisFrame`, applies scalers/clamps, then calls `AddForce`/`AddTorque` (`Classes/AMVehicleAircraft.uc`, around lines 831–849). Thrust is added separately without that time factor. Defaults are `ForceScaler=300` and `TorqueScaler=1` (around lines 1071–1079), so at 1/60 s the pre-clamp aero force is multiplied by 5 while torque is multiplied by about 1/60. This is frame-time-dependent and asymmetrically scaled, but the exact correction must account for the UE3 API contract, force units, and clamps. The Unity reference submits force without multiplying it by `fixedDeltaTime` (`Aircraft-Physics/.../AircraftPhysics.cs`, around lines 41–46). |
| **Fuselage and rudder are defined but absent from the active surface array (confirmed configuration).** | The O1 Bird Dog content class defines both fuselage surfaces and a yaw-controlled rudder, but the active `AeroSurfaceComponents` entries contain only elevators, ailerons, and wings (`Classes/AMAircraft_O1BirdDog_Content.uc`, around lines 341–512 and 514–529). The force loop only visits that array (`AMVehicleAircraft.uc`, around lines 880–897); the control-surface update loop also visits it (around lines 737–765). The user clarified that vertical body surfaces are intended in the eventual model despite their entries being commented out; treat their absence from the active array as incomplete configuration, and map intended surfaces to components/sockets before enabling them. The rudder also receives neither aerodynamic force nor control-angle updates through these loops until it is included. |
| **A component-vs-actor rotation mismatch was alleged, but is not supported by this source.** | `GetAxes(Rotation, ...)` is called inside `AeroSurfaceComponent`, which extends `PrimitiveComponent` (`Classes/AeroSurfaceComponent.uc`, around lines 25 and 124). The airflow is transformed using that same component's `LocalToWorld` transform (around lines 151–155). This is not evidence that the aircraft actor's rotation is being used. Recheck if the implementation changes, but do not treat this prior claim as a confirmed bug. |
| **The force/torque physics boundary needs an explicit UU-based conversion.** | The aero calculation converts velocity with `UU_TO_METERS=0.02`, uses configured `Chord * Span` as area, and converts the lever-arm torque with the same factor (`AeroSurfaceComponent.uc`, around lines 28, 165–169, 197–208). This can produce SI-like N and N·m only if the project's UU-to-meter mapping and configured dimensions are correct. The project convention is that UE3 physics expects engine-native UU-based force/torque quantities; no explicit UE3 API source was found that says these calls accept SI values. The code currently passes calculated values without a clearly named SI-to-engine conversion. `Thrust=3000` is explicitly commented `// Newtons??` (`Classes/AMAircraft_O1BirdDog.uc`, around line 919). Derive and apply conversions at the physics boundary; do not assume the aerodynamic `0.02 m/UU` is also UE3's physics scale. |
| **Controls are updated after the current tick's force calculation.** | `Tick()` calls `CalculateLiftTorqueThrust(DeltaTime)` before `HandleInputs()` (`Classes/AMVehicleAircraft.uc`, around lines 363–370). `HandleInputs()` updates `ThrustPercent` and control-surface `FlapAngle` values (around lines 644–707). Log both the control state consumed by the current force calculation and the newly sampled state for the next one; do not silently reorder behavior as part of telemetry work. |

The archived [UE3 PrimitiveComponent native-function reference](https://wiki.beyondunreal.com/index.php/UE3:PrimitiveComponent_native_functions_(UDK)) distinguishes `AddForce` from `AddImpulse` and describes force magnitude, but does not specify SI units. No source found here explicitly establishes that UE3 `AddForce`/`AddTorque` accepts N/N·m, so use the project's UU-based convention unless exact UE3 engine source proves otherwise.

## Implementation sequence

### 1. Preserve a baseline

- Record the tested aircraft, map, game build, repository revision, physics role/net mode, mass, gravity, scaler values, and logging settings.
- Use a short repeatable scenario: stationary/idle, straight powered acceleration, a level pitch input, roll input, and yaw input. Keep each run short.
- Capture a baseline before changing physics. Do not tune aerodynamic coefficients during this pass.

### 2. Add a bounded UnrealScript telemetry helper

First verify that the target UE3/UDK build exposes a usable native file writer, its permitted output directory, and its behavior in the packaged game. If file writing is unavailable in the target build, stop and choose an approved engine-side export path rather than silently dropping data. Keep the helper small and owned by the aircraft or the logging session; make logging opt-in and easy to close.

Write two comma-separated files with identical `flight_id` and `tick_id` keys:

- `aircraft_ticks.csv`: one row for every aircraft `Tick()` while the session is enabled, including rows where the force calculation is skipped.
- `surface_ticks.csv`: one row per surface visited by the force calculation for that same tick.

Use a session identifier that changes for each capture and reset the signed 32-bit `tick_id` to zero when that session opens. Increment once per logged aircraft tick, not once per surface. At ordinary game rates a session counter will not approach signed 32-bit limits; still close/rotate a session before an exceptionally long capture. Include game time and `DeltaTime` so rows remain diagnosable if a tick is missing.

**Aircraft row fields**

- Keys/time: `flight_id`, `tick_id`, `game_time_s`, `delta_time_s`, and an explicit `aero_calculation_ran` / `force_submitted` indicator.
- Runtime context: role, net mode, physics mode, engine state, health, driving/grounded state, mass, gravity, and center of mass in world coordinates and (if useful) aircraft-local coordinates.
- Transform/motion: world position in UU; raw rotator values plus world-space forward/up axes (or a documented quaternion); velocity in UU/s and converted units; raw angular velocity and a converted value only after its UE3 units are verified.
- Inputs: raw key/mouse values available to the script, clamped pitch/roll/yaw, throttle input, `ThrustPercent`, and the per-surface flap angles. Distinguish the control values consumed by this force calculation from values updated later in the same `Tick()`.
- Applied forces: `ForceThisFrame` and `TorqueThisFrame` before time/scaler/clamp operations; values after each operation; `ThrustForce` separately; and the exact combined vectors passed to `AddForce` and `AddTorque`. Include component-wise values and units in column names or a schema note.

**Surface row fields**

- Keys and identity: `flight_id`, `tick_id`, surface array index, `SurfaceName`, and whether the component is active/included.
- Transform: surface world position, relative position from COM, surface rotation, and world-space chord/forward, span, and normal axes.
- Airflow: world airflow passed in; local airflow before and after the Y projection; local and world drag/lift directions.
- Aerodynamics: angle of attack in radians and degrees, zero-lift/stall angles, stall state, corrected lift slope, aspect ratio, dynamic pressure, area, and lift/drag/tangential coefficients.
- Results: lift, drag, airfoil torque, lever-arm torque, total surface force, and total surface torque before any aircraft-level scaling.

Capture the force inputs and outputs at the point they are actually calculated/submitted, not by reconstructing them later from HUD values. The `Tick()` call is not a solver callback: describe the files as a trace of script calculations and force submissions, never as a complete record of physics integration steps. Confirm which network instance actually applies physics before filtering logs; record role/net mode so client/server duplication is visible.

Implementation requirements:

- Write stable headers once, quote/escape strings, use a locale-independent decimal point, and keep column order fixed. Keep numeric values unrounded enough to compare calculations.
- Buffer rows and flush periodically or at session end rather than synchronously forcing a disk write every frame. Close/flush on explicit stop and normal teardown.
- Report open/write/close failures explicitly through the project's normal logging or user-visible debug mechanism; do not produce a success-shaped empty file.
- Avoid logging every client by default if that creates duplicate captures. Keep the session short and verify that logging does not materially change frame time.
- Include a tiny schema note in the plan or adjacent code comments if a value's units cannot fit unambiguously in its column name.

### 3. Validate telemetry before using it

- Parse both files with a CSV parser and verify headers, row counts, numeric fields, and session/tick joins.
- For each tick where aero ran, verify that the surface-row count equals the number of components traversed by `AeroSurfaceComponents`.
- Recompute summed surface forces/torques from the surface rows and compare with the aircraft's pre-scaling totals. Compare final logged vectors with the values passed to physics.
- Confirm time, `DeltaTime`, role, and control-state values match a short in-game capture. Check specifically that input changes and resulting `FlapAngle`/throttle values are associated with the expected current or next tick.
- Retain the raw log and a brief description of the maneuver for each test run.

### 4. Correct lift direction in isolation

- Define the intended surface frame explicitly: current code treats local X-Z as the airfoil section plane and local Y as the ignored spanwise direction. Confirm this against the attached socket transforms in the actual aircraft mesh.
- Compute lift in the airfoil section plane using the surface span axis (the normal to that section plane), not the chord/forward vector. Choose cross-product order and any sign correction from a controlled test, not guesswork.
- Test a level surface with zero, small positive, and small negative angle of attack. Require finite values, zero lift at zero lift coefficient, positive-AoA lift toward aircraft-local +Z in the agreed reference orientation, and sign reversal for negative AoA. Repeat on both left and right wings and control surfaces to catch mirrored socket axes.
- Keep drag direction and coefficient calculations unchanged during this isolated correction. Compare the surface CSV before/after, then test in game.

### 5. Resolve force, timestep, and unit semantics

- Use UU-based engine-native force and torque quantities at the UE3 physics boundary unless exact UE3 engine source explicitly specifies SI units. Inspect the target build's mass, time, length, and physics-scale conventions; do not pass SI N/N·m directly without a documented conversion.
- In the actual UE3 build, verify whether the force-submission API accepts continuous force or impulse and whether it applies the solver timestep internally. Use API/source documentation for the exact engine version and a controlled in-game test.
- Run the same steady-force test for equal simulated durations at different frame rates. A continuous force should not change merely because the render/game tick interval changed. Compare acceleration and logged submitted force.
- If `AddForce`/`AddTorque` are continuous-force APIs, submit force and torque rather than multiplying them by `DeltaTime`; use an impulse API only when intentionally submitting impulse. Do not carry the existing 300/1 scalers forward as implicit unit conversions.
- Establish and document one conversion boundary for length, velocity, force, and torque. Verify whether `0.02 m/UU` matches the model's actual scale; verify `Chord` and `Span` are in meters before using them as square-meter inputs. Convert calculated SI-like force/torque and thrust into the verified UE3-native units exactly once before submission; confirm whether `Thrust=3000` is newtons or engine units.
- Re-test with force/torque scalers set to an explicit neutral value, then tune only after the dimensional conversion and frame-rate behavior are stable. Keep clamps visible in the log so a clamp does not conceal an upstream scale error.

### 6. Restore intended surface coverage

- Include the intended vertical body surfaces in the final surface inventory even though their entries are currently commented out. Identify their component/socket mapping and verify local axes, area, zero-lift/stall settings, and intended drag/lift behavior before adding them to the active array.
- Add the rudder to the active array if yaw control is intended. Verify its socket axes and control sign; because control updates iterate over the same list, adding it changes both aerodynamic calculation and rudder animation/control-angle updates.
- Ensure every configured surface appears exactly once in the array and that no inactive surface is accidentally processed.

### 7. Validate and tune after fixes

Run the same baseline maneuvers with logging enabled and then disabled. Check:

- At zero airspeed, aerodynamic forces are zero or appropriately negligible and all values remain finite.
- At positive airspeed, drag opposes aircraft velocity; lift sign and magnitude respond consistently to angle of attack.
- Left/right wing forces are symmetric at zero roll input and produce the expected differential with roll input.
- Pitch, roll, and yaw controls change the intended surface angles and aircraft moments; the rudder contributes when enabled.
- Equal-duration runs at different tick rates have comparable force-driven behavior, allowing for expected solver differences.
- No force clamp is unexpectedly active during ordinary flight and thrust/aero magnitudes use the same documented unit system.
- The aircraft remains stable through straight flight, moderate turns, and recovery from small disturbances before attempting aggressive maneuvers or coefficient tuning.

Change one class of behavior at a time (lift-axis math, force/timestep/unit boundary, surface membership, then coefficient tuning), retain a before/after CSV for each change, and revert only the change that fails its acceptance checks.

### 8. Nice-to-have: offline trace explorer and playback

After the logger schema is stable, add an optional Python utility that turns a capture into an inspectable 3D flight playback. This is a visualization of recorded states, not a replacement for the UE3 physics solver.

Prototype the presentation first with generated in-memory poses and vectors; defer CSV parsing, Polars joins, and UE3 coordinate conversion until the drawing conventions and controls are usable. The initial prototype must clearly label its synthetic data and display coordinates, and should not imply a faithful reconstruction of an actual aircraft or flight.

The initial slice now lives in `tools/flight_trace_viewer/`: `src/flight_trace_viewer/app.py` renders the synthetic 3D flight, code-only aircraft glyph, per-aircraft/per-surface vectors, right-hand-rule torque arcs, and slider/play/rewind/speed/visibility controls. `tests/test_presentation.py` checks the demo frame math and key presentation controls. It intentionally does not read or interpret capture files.

The UnrealScript logger interface is scaffolded in `Classes/AMFlightCsvLogger.uc` with session, tick, surface-row, aircraft-row, and stop entry points. It is intentionally non-writing. `tuokri/UDK-Lite/Development/Src/Engine/Classes/FileWriter.uc` shows that UE3 `FileWriter` extends `Info`, writes with `Logf()`, and opens files in engine-managed locations selected by `FWFT_*`; its default flushes every write, so set `bFlushEachWrite=false` for per-tick telemetry. This is a UDK engine reference, not the RS2 SDK itself; verify the exact target build before implementing or wiring file output.

- Load `aircraft_ticks.csv` and `surface_ticks.csv`, select a `flight_id`, validate required columns, and join surface data by `(flight_id, tick_id)`. Handle irregular `DeltaTime`, missing rows, and duplicate keys explicitly rather than assuming a fixed frame rate.
- Build surface artists and visibility controls from the capture's surface names rather than assuming a fixed set, so vertical body surfaces and later aircraft configurations can be displayed independently.
- Keep the CSV values as raw UE3 data and perform all display conversion in one explicit UE3-to-view-frame function. Document the source axis convention, rotator/basis meaning, unit scales, and the chosen viewer convention; do not assume NumPy or Matplotlib defines the same handedness or "up" axis as UE3. Distinguish a passive coordinate-basis conversion from an active reflection of the represented geometry: derive torque/angular-velocity mapping from the actual source/destination basis and cross-product conventions rather than blindly copying the position/force mapping. For an active reflection, axial vectors use the determinant sign as well as the matrix transform.
- Draw the aircraft trajectory in 3D and show its orientation with a code-only aircraft glyph: a forward fuselage/nose, left and right wings, tailplane, and vertical fin. Build the glyph from simple local-space line segments or triangles transformed by the logged aircraft forward/up axes (or a documented quaternion); do not require a mesh asset. Keep the glyph visible and legible at the selected time, with an optional heading/up-axis indicator.
- Provide play/pause, rewind, playback-speed choices, jump-to-time, and a time slider. Selecting a time should update the aircraft pose and show the corresponding state, control inputs, and optional per-surface force/lift/drag arrows.
- Draw linear velocity and all forces as straight arrows. Draw torque as a circular arrow around an axis aligned with its torque vector, with rotation direction following the right-hand rule. Place aircraft-level torque glyphs at the center of mass and surface torque glyphs at their surface positions. Indicate torque magnitude with a labeled value or an explicitly independent display scale; do not imply that the drawn circle radius is a physical distance.
- Provide independent visibility toggles for aircraft linear velocity, angular velocity, thrust, net aerodynamic force, total submitted force, and total torque glyphs. Provide a separate toggle for each named aerodynamic surface and independent toggles for each surface's lift, drag, resultant force, aerodynamic torque, and lever-arm torque. Use distinct trace names/colors and show units; give force, torque, and velocity independent display scales so their glyphs remain readable without implying comparable magnitudes. Keep angular velocity distinguishable from torque (for example, retain it as an axis/vector indicator unless a separate rotational glyph is explicitly enabled).
- Show useful synchronized time-series panels such as airspeed, AoA, control inputs, dynamic pressure, force/torque totals, and stall state. Make units and coordinate convention visible; allow axis scaling or a world/local view toggle where practical.
- **Use Polars for all CSV loading, filtering, validation, and joining.** Use NumPy for vector transforms, time lookup, and interpolation; use Matplotlib's 3D axes, `FuncAnimation`, `Slider`, `Button`, and `CheckButtons` for the lightweight interactive viewer. Seaborn is optional for statistical summaries only. Keep viewer dependencies isolated from the UE3 project and make the viewer optional.
- Target Python 3.14. Manage the viewer in its own `uv` project with a committed lockfile; use Ruff for linting/formatting and `ty` for static type checking. Add type hints throughout the viewer, conversion helpers, and numeric kernels. Keep Jupyter as a development/benchmark dependency, not a runtime requirement.
- Use `@dataclass(slots=True)` for fixed-shape record/container dataclasses such as `FlightTrace` and `ViewData`; it prevents accidental dynamic attributes and can reduce per-instance memory. Treat this as a sensible default, not a substitute for profiling: keep large or hot numeric collections in Polars/NumPy arrays rather than allocating one Python dataclass per sample.
- Use Polars-native expressions first for supported filtering, joins, arithmetic, and aggregation; Polars executes those in its own optimized engine. Numba does not compile Polars DataFrames or expressions, so keep custom compute-heavy kernels as NumPy-array functions. The official Polars [`map_batches` guide](https://docs.pola.rs/user-guide/expressions/user-defined-python-functions/) demonstrates calling a Numba-compiled function from a batch UDF after converting a Series to a NumPy array; use that bridge only when it benchmarks well and fits the operation's batching/null semantics. For the viewer's smaller numeric transforms, an explicit Polars-to-NumPy-to-Numba boundary may be simpler. Avoid row-wise UDFs and do not assume a UDF is faster than a native Polars expression.
- Use Numba only for measured, compute-heavy numeric kernels. Keep Polars I/O, Matplotlib artists/widgets, and UI callbacks in ordinary Python; convert selected columns to contiguous NumPy arrays at the kernel boundary. Put cached `@njit(cache=True)` functions in importable `.py` modules (not notebook-only cells) so file caching works. Avoid JIT-compiling small UI callbacks or cheap operations where compilation overhead is greater than the work.
- When raw Python versus Numba performance is uncertain, use a Jupyter notebook to compare equivalent implementations on representative trace sizes. Check numerical agreement first, report first-call compilation separately from warmed steady-state timings, repeat measurements, and include the Python/tool versions and input sizes with the results. Keep the notebook only when a real hot path warrants it; do not add Numba decoration by default.
- Use `game_time_s` for the time slider and `tick_id` for exact row selection. If interpolating between recorded frames for smooth display, interpolate position carefully and use quaternion SLERP (or another rotation-aware method); do not linearly interpolate raw Unreal rotator components across angle wraps.
- Verify conversion with known basis vectors and poses before rendering a flight: UE3 local +X must map to the nose, the logged span axes to the wings, and local +Z to the fin/up direction. Test 90-degree rotations about each source axis and torque signs so the circular arrow's right-hand-rule direction remains correct after conversion. Keep positions in UU if the physical length scale is not verified, and label them as UU rather than silently displaying meters.
- Label this mode **recorded-state playback**. Since the trace is sampled from `Tick()` rather than every physics substep, it cannot guarantee exact deterministic physics replay. A separate approximate re-simulation mode would need initial state, effective controls, applied forces, wind/gravity, mass/inertia, contact state, and solver timing; even then it must be validated against UE3 rather than presented as exact.

#### Camera navigation and renderer choice

The current Matplotlib prototype already has 3D camera navigation through `mplot3d` when run with an interactive GUI backend: left-drag rotates, middle-drag pans, and right-drag up/down zooms. The generic 2D toolbar pan/zoom buttons do not control a 3D axes. These are Matplotlib defaults (`Axes3D.mouse_init`); no extra interaction code is required. The prototype only sets camera orientation and axis limits during initialization, so frame updates should preserve the user's camera. Headless backends such as Agg cannot provide mouse interaction. See the [mplot3d interaction docs](https://matplotlib.org/stable/api/toolkits/mplot3d.html) and [`Axes3D.mouse_init`](https://matplotlib.org/stable/api/_as_gen/mpl_toolkits.mplot3d.axes3d.Axes3D.mouse_init.html).

| Option | Navigation and complexity | Performance / tradeoff |
|---|---|---|
| **Matplotlib (current feature-rich prototype).** | Rotate/pan/zoom are already available and the prototype has the fuller set of overlays and controls. | A target-machine test found its interactive performance horrendous. Retain it as a comparison baseline, not the presumed interactive-renderer choice. |
| **Plotly without Dash.** | Plotly 3D offers built-in camera controls and configurable orbit/pan modes; camera pose can be set via `layout.scene.camera` / `scene_dragmode`. The optional `plotly_renderer.py` scaffold plots a static path and animates the code-drawn aircraft glyph with browser-side frames and basic playback/seek controls. It is not feature-complete: force/torque and surface overlays and CSV loading remain future work. A target-machine test found it much faster than Matplotlib, but the simpler scene makes this a qualitative, non-like-for-like comparison. Moderate porting effort; a browser is used, but a Dash server is not required for a standalone figure. See [3D camera controls](https://plotly.com/python/3d-camera-controls/), [animations](https://plotly.com/python/animations/), and [performance](https://plotly.com/python/performance/). | Plotly 3D traces use browser-side WebGL rendering. Data is still serialized and held in the browser, so large traces and many per-frame traces can increase payload and memory. |
| **Plotly with Dash.** | Adds a local web application, layout, controls, and callbacks. `dcc.Graph` exposes interactions such as `relayoutData`, useful if camera changes must synchronize with other panels. More setup and application state than needed just to navigate a 3D plot. See [Dash interactive graphing](https://dash.plotly.com/interactive-graphing). | Dash itself does not make the 3D renderer faster. Avoid sending a full figure through a Python server callback on every animation frame; preload trace data and use browser-side animation/client-side callbacks where practical. Dash's [performance guidance](https://dash.plotly.com/performance) recommends WebGL and clientside callbacks for relevant workloads. |

#### Prototype performance smoke benchmark

A local benchmark exercised the current synthetic viewer with all overlays enabled using Matplotlib 3.11.2's headless `Agg` backend. The figure was 14 × 9 inches at the default 100 DPI. Each frame-update measurement called `_render_frame()` (including dynamic-artist removal/recreation and `draw_idle()`); each camera-redraw measurement changed `Axes3D.view_init()` and called `canvas.draw()`. The combined case performed both draws sequentially. Values are median / p95 milliseconds:

| Synthetic path samples | Frame update | Camera redraw | Sequential frame + camera |
|---:|---:|---:|---:|
| 320 | 101.0 / 104.4 | 87.7 / 90.9 | 184.6 / 189.7 |
| 10,000 | 101.6 / 104.4 | 88.1 / 90.6 | 183.6 / 187.6 |

The animation interval is 50 ms (nominally 20 FPS), so the measured frame update alone exceeds that interval in this environment. If each animation update and camera movement causes a distinct draw, the combined measurement corresponds to about 5.4 such updates per second. The similar results at 320 and 10,000 path samples suggest path length is not the main cost in this range; the full 3D redraw and dynamic-artist churn are likely more significant, though this benchmark does not isolate their individual costs.

These are CPU-side smoke-test timings, not an interactive GUI or target-machine benchmark: `Agg` has no mouse input or GUI event loop, and its synchronous `draw_idle()` behavior and rendering speed may differ from an interactive backend. The combined measurement also forces two draws rather than measuring how a GUI backend may coalesce them. These local timings do not provide a controlled, feature-matched comparison with Plotly, and WebGL documentation alone does not establish a comparative frame rate.

A separate owner-reported test on the target machine found Matplotlib's interactive performance horrendous and Plotly much faster. No timings were recorded here, and the Plotly scene is substantially simpler than the Matplotlib scene, so this is directional evidence rather than a feature-matched benchmark.

Decision: do not presume Matplotlib is suitable for interactive playback on the target machine. Continue with Plotly as the faster starting point, while recognizing that its current simplicity may hide costs from the full set of overlays and controls; a different, more performant rendering approach may still be needed. Compare equivalent scenes and separate browser/load time from steady-state playback before choosing a final architecture. Every renderer evaluated should display frame time and an FPS counter.

#### Other renderer options and claim caveats

The broad comparison that Plotly is always “vastly faster” or guarantees 60 FPS is too strong. Matplotlib documents `mplot3d` as a 3D-to-2D projection toolkit and notes that it is not the fastest 3D library; Plotly's 3D traces use browser-side WebGL. An owner-reported target-machine test found Plotly much faster than Matplotlib, but the compared scenes were not feature-equivalent and no numeric frame-time/FPS results were recorded here. Treat this as directional evidence, not proof of final-renderer performance: browser/GPU/driver support, WebGL context limits, figure serialization, and preloaded animation frames all matter. The current headless Matplotlib smoke test found similar timings for 320 and 10,000 path points, so it does not support a universal “few thousand points” cutoff. Neither those Agg results nor generic WebGL claims establish the performance of a feature-complete target-machine viewer. See [Matplotlib `mplot3d`](https://matplotlib.org/stable/api/toolkits/mplot3d.html) and [Plotly performance](https://plotly.com/python/performance/).

Do not treat Plotly's depth handling as a blanket guarantee against every overlap, transparency, or ordering artifact; validate the actual aircraft/surface overlays. Matplotlib remains a good option for fixed-camera figures and vector-oriented publication output. Plotly can also export static images, but WebGL layers in SVG/PDF output are raster images rather than true vectors. Interactive Plotly figures require a browser engine (external browser or embedded web view); Kaleido/headless Chrome can produce static images, not browser-free interactive camera controls. See Plotly's [rendering](https://plotly.com/python/renderers/) and [static export](https://plotly.com/python/static-image-export/) guidance.

The alternatives below are native desktop rendering stacks rather than drop-in Plotly replacements. Their potential advantage is direct control of a GPU-backed scene and in-place geometry updates without serializing a figure and its frames for a browser. Plotly already uses WebGL, however, so that architectural difference does not guarantee a higher frame rate:

| Alternative | Potential performance benefit over Plotly | Fit and cost for this viewer |
|---|---|---|
| **PyVista / VTK** | VTK's native rendering pipeline can retain scene actors and update their point data or transforms, avoiding browser startup, figure serialization, and Plotly frame payloads. Its rendering and data pipeline are designed for larger meshes and scientific geometry. | Best alternative if the viewer grows to aircraft meshes, substantial surfaces, or a Qt desktop app. PyVistaQt embeds a VTK interactor and supports non-blocking updates. This is a larger dependency and app architecture; for a small line-and-glyph scene, no performance win over Plotly is established. See [PyVista](https://docs.pyvista.org/) and [PyVistaQt usage](https://qt.pyvista.org/usage.html). |
| **VisPy** | A lower-level OpenGL visual can update GPU buffers directly, which offers the greatest potential to minimize per-frame data and artist overhead for a custom dynamic scene. Its documentation describes it as a high-performance interactive visualization library and exposes deferred GPU buffer uploads. | Most promising if matched tests show that higher-level renderer overhead limits high-rate playback. It requires more custom camera, glyph, control, and time-series UI work, plus a supported OpenGL context/toolkit. See [VisPy](https://vispy.org/vispy.html), [buffer API](https://vispy.org/api/vispy.gloo.buffer.html), and [installation requirements](https://vispy.org/installation.html). |
| **Open3D** | A native interactive visualizer supports non-blocking loops that update geometry and request redraws, potentially avoiding Plotly's browser/serialization path. | Its built-in rendering and geometry workflows are strongest for point clouds and spatial meshes, not synchronized telemetry panels. The newer visualizer requires OpenGL 4.1; documented Linux software rendering is slower. Consider it if point-cloud/geometry processing becomes central, not as the first optimization for this sparse flight path. See [non-blocking visualization](https://www.open3d.org/docs/latest/tutorial/visualization/non_blocking_visualization.html) and [CPU/software rendering](https://www.open3d.org/docs/0.19.0/tutorial/visualization/cpu_rendering.html). |

No controlled, same-hardware comparison was found for PyVista/VTK, VisPy, or Open3D on a 7,200-point flight path with moving aircraft/surface force glyphs. The current trace and small number of surfaces are modest for GPU rendering; the main differences may be figure/frame setup, Python-to-renderer updates, and application architecture rather than raw vertex throughput. Keep Plotly as the first browser-based comparison. Consider PyVista/VTK for a mesh-heavy desktop viewer, or prototype VisPy only if measured playback still misses its target. Do not select any alternative based on generic point-cloud FPS claims.

**Match playback cadence when benchmarking.** The Plotly scaffold's default frame duration is 50 ms. If it plays every one of 7,200 samples in a nominal 60 Hz, two-minute trace, that duration requests about 360 seconds of playback, not 120 seconds. Set `--frame-duration-ms 17` for roughly 60 Hz pacing, or compare 20 Hz playback by first presenting about every third sample with 50 ms frames. Browser scheduling and actual rendering can still miss the requested cadence, so measure elapsed playback time and frame drops rather than assuming the configured duration is achieved. See [Plotly animation frames](https://plotly.com/python/animations/).

#### Compacting long flight traces (light research; not implemented)

The viewer does not load CSVs yet, so there is no real capture-size or display-quality baseline. Treat display decimation separately from storage compression: keep the complete imported rows as the source for exact tick selection, analysis, and export, and create a reduced representation only for rendering. If storage or transfer size is the concern, measure it separately and evaluate lossless compression before considering lossy capture formats. The earlier synthetic benchmark showed similar draw times for 320 and 10,000 path points, so it does not establish that path length alone is a bottleneck; benchmark representative multi-channel captures before choosing a reduction target.

For scale, a 120-second capture at 60 logged ticks per second has 7,200 aircraft rows. The current BirdDog `AeroSurfaceComponents` array has six entries, so if the aerodynamic calculation visits all six each tick, that adds 43,200 surface rows (50,400 rows across both files). Enabling the two commented fuselage/body components would raise this to 64,800 total rows; enabling the rudder as well would raise it to 72,000. These counts assume 60 actual `Tick()` calls per second and a surface calculation every tick; aircraft rows still record ticks where the calculation is skipped, but those ticks do not add surface rows.

The preliminary CSV size estimate is about 42–59 MB with six surfaces and 59–85 MB with nine, using an unfinalized assumption of roughly 1 KB per aircraft row and 0.8–1.2 KB per surface row. This is serialized CSV size, not an estimate of in-memory Polars/NumPy use. Since the 7,200-point trajectory is within the earlier 10,000-point test, those results do not suggest path-point count alone requires compaction. However, the benchmark rendered four demo surfaces, not the current six or possible eight/nine, and did not include the planned time-series panels or an interactive backend; its FPS timings should not be extrapolated to a complete viewer.

- **Scalar time-series panels:** Consider per-pixel time buckets with first/last/min/max retention (M4-style) when preserving local peaks is important, or MinMaxLTTB when a visually representative line with faster preselection is preferred. These techniques are designed for 2D time-series display, not as a general flight-record compressor. See the [MinMaxLTTB paper](https://arxiv.org/abs/2305.00332).
- **3D trajectory:** Consider a Ramer–Douglas–Peucker-style polyline simplifier with a documented 3D point-to-segment deviation tolerance in viewer coordinates. Apply it to the path only; it does not preserve force, torque, or control-signal peaks. The [RDP reference](https://www.mathworks.com/help/images/ref/reducepoly.html) describes 2D line simplification, so a 3D adaptation still needs its own tests.
- **Synchronization and important events:** Select original row indices and keep complete rows. If channels choose points independently, take the union of their retained indices (which may exceed the nominal point budget) rather than combining values from different timestamps into synthetic rows. Always retain endpoints and explicitly pinned event times; consider control transitions, surface/state changes, and force/torque extrema as protected samples.

Future work: generate representative 30-second-to-few-minute traces at the logger's actual sampling rate; compare a scalar-series reducer and a 3D path simplifier without modifying the raw data; then measure retained-point count, render time, playback synchronization, event/peak retention, maximum path deviation, and scalar reconstruction error. Choose tolerances and any point budget from those results rather than fixing them in advance.

Suggested lightweight scaffold: keep the isolated Python project under `tools/flight_trace_viewer/`, not at the UE3 repository root. This keeps Python tooling scoped to the optional viewer and avoids presenting the UnrealScript repository as a Python project. Use `tools/flight_trace_viewer/pyproject.toml` for project metadata and Ruff configuration (add a separate `ruff.toml` only if a real need arises), `tools/flight_trace_viewer/uv.lock` for the pinned environment, and `tools/flight_trace_viewer/src/flight_trace_viewer/app.py` for the application entry point. Keep package, module, and directory names underscored. Put focused tests under `tools/flight_trace_viewer/tests/`; add `tools/flight_trace_viewer/notebooks/benchmark_numba.ipynb` only when a numeric hotspot is uncertain. The source-free prototype is runnable now; the following loader/conversion interfaces describe the later CSV-ingestion phase and should not block presentation iteration.

```python
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import polars as pl
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
from matplotlib.figure import Figure
from matplotlib.widgets import Button, CheckButtons, Slider
from numpy.typing import NDArray


@dataclass(slots=True)
class FlightTrace:
    aircraft: pl.DataFrame
    surfaces: pl.DataFrame


@dataclass(slots=True)
class ViewData:
    aircraft: pl.DataFrame
    surfaces: pl.DataFrame


def load_trace(aircraft_csv: Path, surfaces_csv: Path, flight_id: str) -> FlightTrace:
    """Read with Polars, validate keys/columns, filter one flight, and sort by tick."""
    raise NotImplementedError


def to_view_frame(trace: FlightTrace) -> ViewData:
    """Apply the documented UE3-to-view axis and unit conversions exactly once."""
    raise NotImplementedError


def frame_index_at_time(times_s: np.ndarray, time_s: float) -> int:
    """Find the nearest recorded frame without assuming a fixed timestep."""
    raise NotImplementedError


def aircraft_glyph(
    position: NDArray[np.float64],
    forward: NDArray[np.float64],
    up: NDArray[np.float64],
    scale_uu: float,
) -> list[NDArray[np.float64]]:
    """Return world-space code-only fuselage, wing, tailplane, and fin segments."""
    raise NotImplementedError


def build_viewer(view: ViewData) -> tuple[Figure, FuncAnimation]:
    """Create 3D path/pose, vector overlays, per-surface artists, and UI controls."""
    # Keep one named artist per independently toggleable arrow/surface.
    # Draw force/linear-velocity arrows as straight arrows and torque as
    # right-hand-rule circular arrows about the torque-vector axis.
    # Update existing artists when the slider or animation selects a new frame.
    # Use CheckButtons for per-arrow and per-surface visibility.
    # Use Slider for time; Buttons plus a signed playback rate for play/rewind.
    raise NotImplementedError


def main() -> None:
    """Parse CSV paths and flight_id, build the viewer, and call plt.show()."""
    raise NotImplementedError


if __name__ == "__main__":
    main()
```

Example pattern for a numeric kernel, to adopt only after the benchmark shows it helps:

```python
from numba import njit
import numpy as np
from numpy.typing import NDArray


@njit(cache=True)
def transform_points(
    points: NDArray[np.float64],
    rotation: NDArray[np.float64],
    translation: NDArray[np.float64],
) -> NDArray[np.float64]:
    """Transform a batch of points; keep this in an importable .py module for disk caching."""
    transformed = np.empty_like(points)
    for point_index in range(points.shape[0]):
        for axis in range(3):
            transformed[point_index, axis] = translation[axis]
            for source_axis in range(3):
                transformed[point_index, axis] += (
                    rotation[axis, source_axis] * points[point_index, source_axis]
                )
    return transformed
```

Acceptance checks for this optional utility:

- It opens both CSVs for a capture, reports malformed/missing data clearly, and never silently mismatches aircraft and surface rows.
- Known UE3 basis vectors, aircraft poses, and torque signs map to the intended viewer axes; raw CSV values remain available for inspection.
- The displayed path and pose agree with logged world positions/orientations; seeking to a time selects the correct sample.
- The code-only glyph makes heading, bank, and pitch immediately apparent without external model assets.
- Straight-arrow direction matches force/linear-velocity vectors; torque-circle direction matches the right-hand rule, and zero torque does not create an invalid glyph.
- Playback can pause, rewind, change speed, and seek with the slider without changing the underlying trace.
- In an interactive desktop backend, users can rotate by left-dragging, pan by middle-dragging, and zoom by right-dragging vertically; playback updates do not reset the camera.
- Each aircraft vector arrow and each surface's geometry/vector overlays can be hidden or shown independently.
- Force and surface overlays use the logged coordinate frame and units, and playback remains usable for a representative short flight.
- From `tools/flight_trace_viewer/`, `uv run ruff check`, `uv run ruff format --check`, and `uv run ty check` pass; any Numba kernel has a notebook showing correctness and warmed performance versus the pure-Python baseline.

## Completion criteria

- The logger produces parseable, joinable aircraft and surface traces with explicit timing and units, and closes cleanly.
- The force values in the CSV can be independently recomputed and match the values submitted to physics.
- Lift direction passes the controlled orientation/sign checks on both wings.
- Force/torque submission is demonstrably frame-rate independent for a constant-force test and uses verified units.
- The active surface list matches the intended aircraft configuration, including functioning yaw control if the rudder is enabled.
- Repeatable in-game tests show a materially improved and stable response without relying on unexplained scalers.
- The optional trace explorer provides scrubbable recorded-state playback; this is a nice-to-have and does not block the flight-model fixes.
