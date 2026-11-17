# Copyright (c) 2026 Tuomo Kriikkula
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

"""Early Plotly/WebGL renderer scaffold for later performance comparison."""

from __future__ import annotations

import argparse
from typing import TYPE_CHECKING

from flight_trace_viewer.app import GLYPH_SEGMENTS
from flight_trace_viewer.app import DemoTrace
from flight_trace_viewer.app import make_demo_trace

if TYPE_CHECKING:
    import plotly.graph_objects as go


def _glyph_coordinates(
    trace: DemoTrace,
    frame_index: int,
) -> tuple[list[float | None], list[float | None], list[float | None]]:
    """Return aircraft line segments as Plotly coordinates separated by None."""
    if not 0 <= frame_index < len(trace.times_s):
        raise IndexError(f"frame_index out of range: {frame_index}")

    position = trace.positions[frame_index]
    rotation = trace.rotation_matrices[frame_index]
    coordinates: tuple[list[float | None], list[float | None], list[float | None]] = (
        [],
        [],
        [],
    )
    for local_segment in GLYPH_SEGMENTS:
        world_segment = position + local_segment @ rotation.T
        for point in world_segment:
            for axis, values in enumerate(coordinates):
                values.append(float(point[axis]))
        for values in coordinates:
            values.append(None)
    return coordinates


def build_plotly_figure(
    trace: DemoTrace,
    frame_duration_ms: int = 50,
) -> go.Figure:
    """Build a standalone figure with a static path and animated aircraft glyph."""
    try:
        import plotly.graph_objects as go
    except ModuleNotFoundError as error:
        if error.name == "plotly":
            raise RuntimeError(
                "The Plotly renderer is optional; install it with `uv sync --extra plotly`."
            ) from error
        raise

    path = go.Scatter3d(
        x=trace.positions[:, 0],
        y=trace.positions[:, 1],
        z=trace.positions[:, 2],
        mode="lines",
        name="Flight path",
        line={"color": "#707070", "width": 4},
    )
    glyph_coordinates = _glyph_coordinates(trace, 0)
    aircraft = go.Scatter3d(
        x=glyph_coordinates[0],
        y=glyph_coordinates[1],
        z=glyph_coordinates[2],
        mode="lines",
        name="Aircraft",
        line={"color": "#17202a", "width": 6},
        connectgaps=False,
    )
    frames = []
    for frame_index, time_s in enumerate(trace.times_s):
        frame_coordinates = _glyph_coordinates(trace, frame_index)
        frames.append(
            go.Frame(
                name=str(frame_index),
                data=[
                    go.Scatter3d(
                        x=frame_coordinates[0],
                        y=frame_coordinates[1],
                        z=frame_coordinates[2],
                    )
                ],
                traces=[1],
                layout={"title": f"Plotly flight trace | t={time_s:.2f} s"},
            )
        )

    frame_names = [frame.name for frame in frames]
    slider_stride = max(1, (len(frame_names) + 499) // 500)
    slider_indices = list(range(0, len(frame_names), slider_stride))
    if frame_names and slider_indices[-1] != len(frame_names) - 1:
        slider_indices.append(len(frame_names) - 1)
    slider_steps = [
        {
            "args": [
                [frame_name],
                {
                    "frame": {"duration": 0, "redraw": True},
                    "mode": "immediate",
                    "transition": {"duration": 0},
                },
            ],
            "label": f"{trace.times_s[int(frame_name)]:.1f}",
            "method": "animate",
        }
        for frame_name in (frame_names[index] for index in slider_indices)
    ]

    figure = go.Figure(data=[path, aircraft], frames=frames)
    figure.update_layout(
        title="Plotly flight trace | synthetic demo",
        scene={
            "xaxis_title": "X forward (demo units)",
            "yaxis_title": "Y right (demo units)",
            "zaxis_title": "Z up (demo units)",
            "aspectmode": "data",
            "dragmode": "orbit",
        },
        updatemenus=[
            {
                "type": "buttons",
                "showactive": False,
                "buttons": [
                    {
                        "label": "Play",
                        "method": "animate",
                        "args": [
                            None,
                            {
                                "frame": {
                                    "duration": frame_duration_ms,
                                    "redraw": True,
                                },
                                "fromcurrent": True,
                                "transition": {"duration": 0},
                            },
                        ],
                    },
                    {
                        "label": "Pause",
                        "method": "animate",
                        "args": [
                            [None],
                            {
                                "frame": {"duration": 0, "redraw": False},
                                "mode": "immediate",
                            },
                        ],
                    },
                ],
            }
        ],
        sliders=[
            {
                "active": 0,
                "currentvalue": {"prefix": "Frame time (s): "},
                "steps": slider_steps,
            }
        ],
        margin={"l": 0, "r": 0, "t": 55, "b": 0},
    )
    return figure


def main() -> None:
    """Open the synthetic Plotly renderer in a browser."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--samples",
        type=int,
        default=320,
        help="number of synthetic poses to generate",
    )
    parser.add_argument(
        "--duration-seconds",
        type=float,
        default=24.0,
        help="duration represented by the synthetic trace",
    )
    parser.add_argument(
        "--frame-duration-ms",
        type=int,
        default=50,
        help="requested browser animation frame duration",
    )
    args = parser.parse_args()
    if args.samples < 2:
        parser.error("--samples must be at least 2")
    if args.duration_seconds <= 0.0:
        parser.error("--duration-seconds must be greater than zero")
    if args.frame_duration_ms < 0:
        parser.error("--frame-duration-ms must not be negative")

    figure = build_plotly_figure(
        make_demo_trace(
            sample_count=args.samples,
            duration_s=args.duration_seconds,
        ),
        args.frame_duration_ms,
    )
    figure.show(config={"displaylogo": False, "responsive": True, "scrollZoom": True})


if __name__ == "__main__":
    main()
