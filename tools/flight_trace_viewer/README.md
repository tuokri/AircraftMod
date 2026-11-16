# Flight Trace Viewer Prototype

This is a presentation prototype for an interactive 3D aircraft trace viewer.
It currently uses generated demo data; loading UE3 CSV files and converting
their coordinate system are intentionally deferred.

The demo shows a code-drawn aircraft, a synthetic path, straight velocity and
force arrows, right-hand-rule torque circles, per-surface force overlays, and
interactive playback controls.

From this directory, run:

```sh
uv run flight_trace_viewer
```

Run tests with:

```sh
uv run pytest
```

Use the time slider to seek, **Play** to toggle playback, **Rewind** to play
backwards from the end, and **Speed** to cycle playback rates. The checkbox
panel independently controls aircraft vectors and each surface marker/vector.

With an interactive Matplotlib backend, use left-drag to rotate the 3D view,
middle-drag to pan, and right-drag up/down to zoom. The standard 2D toolbar
pan/zoom buttons do not control `mplot3d`; headless backends such as Agg do not
provide mouse interaction.

The local headless Agg smoke benchmark measured about 101 ms per frame update
and 185 ms for an update followed by a separate camera redraw. That is slower
than the prototype's nominal 20 FPS cadence, but is not an interactive GUI or
target-machine measurement; see the [detailed results](../../FLIGHT_MODEL_IMPLEMENTATION_PLAN.md#prototype-performance-smoke-benchmark).

Long-trace CSV loading and display compaction are not implemented. The current
plan favors rendering-only reduction while preserving raw samples for exact
selection and analysis; see the [long-trace research](../../FLIGHT_MODEL_IMPLEMENTATION_PLAN.md#compacting-long-flight-traces-light-research-not-implemented).
A nominal two-minute, 60 Hz capture is about 7,200 aircraft rows and 43,200
surface rows with the current six active surfaces; see the plan for file-size
assumptions and why this does not imply a need to compact the rendered path.

All positions, forces, torques, and velocities are illustrative demo units.
The prototype uses an X-forward, Y-right, Z-up right-handed display frame; it
does not yet define the UE3-to-viewer conversion.
