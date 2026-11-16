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

All positions, forces, torques, and velocities are illustrative demo units.
The prototype uses an X-forward, Y-right, Z-up right-handed display frame; it
does not yet define the UE3-to-viewer conversion.
