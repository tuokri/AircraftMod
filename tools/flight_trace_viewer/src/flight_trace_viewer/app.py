"""Interactive Matplotlib presentation prototype using synthetic flight data."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from itertools import count
from typing import cast

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.animation import FuncAnimation
from matplotlib.artist import Artist
from matplotlib.figure import Figure
from matplotlib.widgets import Button
from matplotlib.widgets import CheckButtons
from matplotlib.widgets import Slider
from mpl_toolkits.mplot3d.art3d import Line3D
from mpl_toolkits.mplot3d.axes3d import Axes3D
from numpy.typing import NDArray

FloatArray = NDArray[np.float64]

SURFACE_NAMES = ("left_wing", "right_wing", "elevator", "rudder")
SURFACE_COLORS = {
    "left_wing": "#1f77b4",
    "right_wing": "#17becf",
    "elevator": "#9467bd",
    "rudder": "#8c564b",
}
SURFACE_POSITIONS = np.array(
    (
        (-12.0, -34.0, 0.0),
        (-12.0, 34.0, 0.0),
        (-28.0, 0.0, 0.0),
        (-26.0, 0.0, 4.0),
    ),
    dtype=np.float64,
)
GLYPH_SEGMENTS = (
    np.array(((40.0, 0.0, 0.0), (-34.0, 0.0, 0.0)), dtype=np.float64),
    np.array(((31.0, -6.0, 0.0), (40.0, 0.0, 0.0)), dtype=np.float64),
    np.array(((40.0, 0.0, 0.0), (31.0, 6.0, 0.0)), dtype=np.float64),
    np.array(((-4.0, -38.0, 0.0), (-4.0, 38.0, 0.0)), dtype=np.float64),
    np.array(((-27.0, -17.0, 0.0), (-27.0, 17.0, 0.0)), dtype=np.float64),
    np.array(((-28.0, 0.0, 0.0), (-20.0, 0.0, 13.0)), dtype=np.float64),
)


@dataclass(slots=True)
class DemoTrace:
    """Small in-memory trace; source-file parsing is intentionally out of scope."""

    times_s: FloatArray
    positions: FloatArray
    rotations: FloatArray
    rotation_matrices: FloatArray
    velocities: FloatArray
    angular_velocities: FloatArray
    thrust: FloatArray
    aero_force: FloatArray
    total_torque: FloatArray
    surface_positions: FloatArray
    surface_lift: FloatArray
    surface_drag: FloatArray
    surface_torque: FloatArray


def rotation_matrix(yaw: float, pitch: float, roll: float) -> FloatArray:
    """Return a right-handed X-forward, Y-right, Z-up demo rotation matrix."""
    cos_yaw, sin_yaw = np.cos(yaw), np.sin(yaw)
    cos_pitch, sin_pitch = np.cos(pitch), np.sin(pitch)
    cos_roll, sin_roll = np.cos(roll), np.sin(roll)

    rotate_z = np.array(
        (
            (cos_yaw, -sin_yaw, 0.0),
            (sin_yaw, cos_yaw, 0.0),
            (0.0, 0.0, 1.0),
        ),
        dtype=np.float64,
    )
    rotate_y = np.array(
        (
            (cos_pitch, 0.0, -sin_pitch),
            (0.0, 1.0, 0.0),
            (sin_pitch, 0.0, cos_pitch),
        ),
        dtype=np.float64,
    )
    rotate_x = np.array(
        (
            (1.0, 0.0, 0.0),
            (0.0, cos_roll, -sin_roll),
            (0.0, sin_roll, cos_roll),
        ),
        dtype=np.float64,
    )
    return rotate_z @ rotate_y @ rotate_x


def make_demo_trace(sample_count: int = 320, duration_s: float = 24.0) -> DemoTrace:
    """Generate an illustrative turning climb, not a flight-model simulation."""
    times_s = np.linspace(0.0, duration_s, sample_count, dtype=np.float64)
    positions = np.column_stack(
        (
            18.0 * times_s,
            90.0 * np.sin(0.19 * times_s),
            105.0 + 24.0 * np.sin(0.42 * times_s),
        )
    )
    velocities = np.gradient(positions, times_s, axis=0)
    yaw = np.arctan2(velocities[:, 1], velocities[:, 0])
    pitch = np.arctan2(
        velocities[:, 2],
        np.hypot(velocities[:, 0], velocities[:, 1]),
    )
    roll = 0.34 * np.sin(0.19 * times_s)
    rotations = np.column_stack((yaw, pitch, roll))
    rotation_matrices = np.stack(
        [rotation_matrix(*angles) for angles in rotations],
    )

    sample_count = times_s.size
    surface_count = len(SURFACE_NAMES)
    surface_positions = np.empty(
        (sample_count, surface_count, 3),
        dtype=np.float64,
    )
    surface_lift = np.zeros_like(surface_positions)
    surface_drag = np.zeros_like(surface_positions)
    surface_torque = np.zeros_like(surface_positions)

    for frame_index, time_s in enumerate(times_s):
        rotation = rotation_matrices[frame_index]
        surface_positions[frame_index] = positions[frame_index] + SURFACE_POSITIONS @ rotation.T
        wing_lift = 78.0 + 16.0 * np.sin(0.45 * time_s)
        surface_lift[frame_index, 0] = (0.0, 0.0, wing_lift * 0.92)
        surface_lift[frame_index, 1] = (0.0, 0.0, wing_lift * 1.08)
        surface_lift[frame_index, 2] = (0.0, 0.0, 13.0 * np.sin(0.7 * time_s))
        surface_lift[frame_index, 3] = (0.0, 9.0 * np.sin(0.3 * time_s), 0.0)
        surface_drag[frame_index, 0] = (-18.0, 0.0, 0.0)
        surface_drag[frame_index, 1] = (-18.0, 0.0, 0.0)
        surface_drag[frame_index, 2] = (-5.0, 0.0, 0.0)
        surface_drag[frame_index, 3] = (-2.0, 0.0, 0.0)
        surface_torque[frame_index, 0] = (0.0, 0.0, 2.4 * np.sin(0.4 * time_s))
        surface_torque[frame_index, 1] = (0.0, 0.0, -2.0 * np.sin(0.4 * time_s))
        surface_torque[frame_index, 2] = (0.0, 3.2 * np.sin(0.55 * time_s), 0.0)
        surface_torque[frame_index, 3] = (0.8 * np.cos(0.3 * time_s), 0.0, 0.0)

    world_lift = np.einsum("nij,nsj->nsi", rotation_matrices, surface_lift)
    world_drag = np.einsum("nij,nsj->nsi", rotation_matrices, surface_drag)
    world_surface_torque = np.einsum(
        "nij,nsj->nsi",
        rotation_matrices,
        surface_torque,
    )
    relative_positions = surface_positions - positions[:, np.newaxis, :]
    total_torque = np.sum(
        world_surface_torque + np.cross(relative_positions, world_lift + world_drag),
        axis=1,
    )
    aero_force = np.sum(world_lift + world_drag, axis=1)
    thrust = np.einsum(
        "nij,nj->ni",
        rotation_matrices,
        np.tile(np.array((155.0, 0.0, 0.0)), (sample_count, 1)),
    )
    angular_velocities = np.gradient(rotations, times_s, axis=0)

    return DemoTrace(
        times_s=times_s,
        positions=positions,
        rotations=rotations,
        rotation_matrices=rotation_matrices,
        velocities=velocities,
        angular_velocities=angular_velocities,
        thrust=thrust,
        aero_force=aero_force,
        total_torque=total_torque,
        surface_positions=surface_positions,
        surface_lift=world_lift,
        surface_drag=world_drag,
        surface_torque=world_surface_torque,
    )


def torque_arc(
    origin: FloatArray,
    torque: FloatArray,
    radius: float = 15.0,
) -> tuple[FloatArray, FloatArray]:
    """Return a right-hand-rule torque arc and its end tangent."""
    axis = torque / np.linalg.norm(torque)
    reference = np.array((1.0, 0.0, 0.0))
    if abs(float(np.dot(axis, reference))) > 0.85:
        reference = np.array((0.0, 1.0, 0.0))
    basis_u = np.cross(axis, reference)
    basis_u /= np.linalg.norm(basis_u)
    basis_v = np.cross(axis, basis_u)
    angles = np.linspace(0.0, 1.65 * np.pi, 48)
    circle = origin + radius * (
        np.cos(angles)[:, np.newaxis] * basis_u + np.sin(angles)[:, np.newaxis] * basis_v
    )
    end_angle = angles[-1]
    tangent = -np.sin(end_angle) * basis_u + np.cos(end_angle) * basis_v
    return circle, tangent


class FlightPresentation:
    """Owns the Matplotlib artists and controls for one presentation prototype."""

    def __init__(self, trace: DemoTrace) -> None:
        self.trace = trace
        self.index = 0
        self.playing = False
        self.playback_rate = 1.0
        self._dynamic_artists: list[Artist] = []
        self._surface_markers: list[Line3D] = []
        self._glyph_lines: list[Line3D] = []
        self.figure: Figure = plt.figure(figsize=(14.0, 9.0))
        self.axes = cast(
            Axes3D,
            self.figure.add_axes((0.045, 0.23, 0.68, 0.72), projection="3d"),
        )
        self._configure_axes()
        self._create_glyph()
        self._create_surface_markers()
        self._create_controls()
        self._render_frame(0)
        self.animation = FuncAnimation(
            self.figure,
            self._advance_playback,
            frames=count(),
            interval=50,
            blit=False,
            cache_frame_data=False,
        )

    def _configure_axes(self) -> None:
        positions = self.trace.positions
        minimum = positions.min(axis=0) - np.array((65.0, 80.0, 45.0))
        maximum = positions.max(axis=0) + np.array((65.0, 80.0, 45.0))
        spans = maximum - minimum
        self.axes.set_xlim(minimum[0], maximum[0])
        self.axes.set_ylim(minimum[1], maximum[1])
        self.axes.set_zlim(minimum[2], maximum[2])
        self.axes.set_box_aspect(spans)
        self.axes.set_xlabel("X forward (demo units)")
        self.axes.set_ylabel("Y right (demo units)")
        self.axes.set_zlabel("Z up (demo units)")
        self.axes.set_title("Synthetic flight presentation prototype")
        self.axes.view_init(elev=25.0, azim=-58.0)
        self.axes.plot(
            positions[:, 0],
            positions[:, 1],
            positions[:, 2],
            color="#707070",
            linewidth=1.2,
            alpha=0.7,
        )
        self.axes.scatter(*positions[0], color="black", marker="o", s=18)

    def _create_glyph(self) -> None:
        for segment in GLYPH_SEGMENTS:
            (line,) = self.axes.plot(
                segment[:, 0],
                segment[:, 1],
                segment[:, 2],
                color="#17202a",
                linewidth=2.8,
                solid_capstyle="round",
            )
            self._glyph_lines.append(line)

    def _create_surface_markers(self) -> None:
        for surface_name in SURFACE_NAMES:
            (marker,) = self.axes.plot(
                [],
                [],
                [],
                color=SURFACE_COLORS[surface_name],
                marker="o",
                markersize=5.0,
                linestyle="None",
                label=surface_name,
            )
            self._surface_markers.append(marker)

    def _create_controls(self) -> None:
        labels = [
            "Aircraft velocity",
            "Thrust",
            "Total aero force",
            "Aircraft torque",
            "Angular velocity",
        ]
        for surface_name in SURFACE_NAMES:
            labels.extend(
                (
                    f"Show {surface_name}",
                    f"{surface_name} lift",
                    f"{surface_name} drag",
                    f"{surface_name} torque",
                )
            )

        self._control_labels = tuple(labels)
        check_axes = self.figure.add_axes((0.76, 0.25, 0.23, 0.69))
        self.check_buttons = CheckButtons(
            check_axes,
            labels,
            actives=[True] * len(labels),
        )
        for label in self.check_buttons.labels:
            label.set_fontsize(8.0)
        self.check_buttons.on_clicked(self._on_visibility_changed)

        slider_axes = self.figure.add_axes((0.12, 0.15, 0.58, 0.035))
        self.time_slider = Slider(
            slider_axes,
            "Time (s)",
            float(self.trace.times_s[0]),
            float(self.trace.times_s[-1]),
            valinit=float(self.trace.times_s[0]),
        )
        self.time_slider.on_changed(self._on_time_changed)

        play_axes = self.figure.add_axes((0.12, 0.055, 0.10, 0.055))
        self.play_button = Button(play_axes, "Play")
        self.play_button.on_clicked(self._toggle_playback)
        rewind_axes = self.figure.add_axes((0.24, 0.055, 0.12, 0.055))
        self.rewind_button = Button(rewind_axes, "Rewind")
        self.rewind_button.on_clicked(self._rewind)
        speed_axes = self.figure.add_axes((0.38, 0.055, 0.12, 0.055))
        self.speed_button = Button(speed_axes, "Speed: 1x")
        self.speed_button.on_clicked(self._cycle_speed)

    def _visibility(self) -> dict[str, bool]:
        return dict(
            zip(
                self._control_labels,
                self.check_buttons.get_status(),
                strict=True,
            )
        )

    def _on_visibility_changed(self, _label: str | None) -> None:
        self._render_frame(self.index)

    def _on_time_changed(self, time_s: float) -> None:
        self.index = int(np.argmin(np.abs(self.trace.times_s - time_s)))
        self._render_frame(self.index)

    def _toggle_playback(self, _event: object) -> None:
        self.playing = not self.playing
        self.play_button.label.set_text("Pause" if self.playing else "Play")
        self.figure.canvas.draw_idle()

    def _rewind(self, _event: object) -> None:
        self.playback_rate = -abs(self.playback_rate)
        self.index = len(self.trace.times_s) - 1
        self.playing = True
        self.play_button.label.set_text("Pause")
        self.time_slider.set_val(float(self.trace.times_s[self.index]))

    def _cycle_speed(self, _event: object) -> None:
        speeds = (0.5, 1.0, 2.0, 4.0)
        direction = -1.0 if self.playback_rate < 0.0 else 1.0
        speed_index = speeds.index(abs(self.playback_rate))
        self.playback_rate = direction * speeds[(speed_index + 1) % len(speeds)]
        self.speed_button.label.set_text(f"Speed: {abs(self.playback_rate):g}x")
        self.figure.canvas.draw_idle()

    def _advance_playback(self, _frame_number: int) -> tuple[Artist, ...]:
        if not self.playing:
            return ()

        current_time = float(self.trace.times_s[self.index])
        next_time = current_time + 0.05 * self.playback_rate
        first_time = float(self.trace.times_s[0])
        last_time = float(self.trace.times_s[-1])
        if next_time <= first_time or next_time >= last_time:
            next_time = float(np.clip(next_time, first_time, last_time))
            self.playing = False
            self.play_button.label.set_text("Play")
        self.time_slider.set_val(next_time)
        return ()

    def _remove_dynamic_artists(self) -> None:
        for artist in self._dynamic_artists:
            artist.remove()
        self._dynamic_artists.clear()

    def _add_vector(
        self,
        origin: FloatArray,
        vector: FloatArray,
        scale: float,
        color: str,
    ) -> None:
        if np.linalg.norm(vector) < 1e-8:
            return
        arrow = self.axes.quiver(
            *origin,
            *(vector * scale),
            color=color,
            linewidth=1.8,
            arrow_length_ratio=0.18,
            normalize=False,
        )
        self._dynamic_artists.append(arrow)

    def _add_torque_glyph(
        self,
        origin: FloatArray,
        torque: FloatArray,
        color: str,
    ) -> None:
        magnitude = float(np.linalg.norm(torque))
        if magnitude < 1e-8:
            return

        radius = 15.0
        circle, tangent = torque_arc(origin, torque, radius)
        (ring,) = self.axes.plot(
            circle[:, 0],
            circle[:, 1],
            circle[:, 2],
            color=color,
            linewidth=2.0,
        )
        self._dynamic_artists.append(ring)

        end_point = circle[-1]
        arrow = self.axes.quiver(
            *end_point,
            *(tangent * radius * 0.42),
            color=color,
            linewidth=1.8,
            arrow_length_ratio=0.55,
            normalize=False,
        )
        self._dynamic_artists.append(arrow)

    def _render_frame(self, index: int) -> None:
        index = int(np.clip(index, 0, len(self.trace.times_s) - 1))
        self.index = index
        visibility = self._visibility()
        position = self.trace.positions[index]
        rotation = self.trace.rotation_matrices[index]

        for line, local_segment in zip(self._glyph_lines, GLYPH_SEGMENTS):
            world_segment = position + local_segment @ rotation.T
            line.set_data_3d(
                world_segment[:, 0],
                world_segment[:, 1],
                world_segment[:, 2],
            )

        for surface_index, marker in enumerate(self._surface_markers):
            surface_name = SURFACE_NAMES[surface_index]
            visible = visibility[f"Show {surface_name}"]
            surface_position = self.trace.surface_positions[index, surface_index]
            marker.set_data_3d(
                [surface_position[0]],
                [surface_position[1]],
                [surface_position[2]],
            )
            marker.set_visible(visible)

        self._remove_dynamic_artists()
        if visibility["Aircraft velocity"]:
            self._add_vector(position, self.trace.velocities[index], 2.0, "#2c3e50")
        if visibility["Thrust"]:
            self._add_vector(position, self.trace.thrust[index], 0.5, "#e67e22")
        if visibility["Total aero force"]:
            self._add_vector(position, self.trace.aero_force[index], 0.65, "#2980b9")
        if visibility["Angular velocity"]:
            self._add_vector(
                position,
                self.trace.angular_velocities[index],
                24.0,
                "#8e44ad",
            )
        if visibility["Aircraft torque"]:
            self._add_torque_glyph(
                position,
                self.trace.total_torque[index],
                "#c0392b",
            )

        for surface_index, surface_name in enumerate(SURFACE_NAMES):
            if not visibility[f"Show {surface_name}"]:
                continue
            surface_position = self.trace.surface_positions[index, surface_index]
            if visibility[f"{surface_name} lift"]:
                self._add_vector(
                    surface_position,
                    self.trace.surface_lift[index, surface_index],
                    0.42,
                    SURFACE_COLORS[surface_name],
                )
            if visibility[f"{surface_name} drag"]:
                self._add_vector(
                    surface_position,
                    self.trace.surface_drag[index, surface_index],
                    1.1,
                    "#7f8c8d",
                )
            if visibility[f"{surface_name} torque"]:
                self._add_torque_glyph(
                    surface_position,
                    self.trace.surface_torque[index, surface_index],
                    "#d35400",
                )

        time_s = self.trace.times_s[index]
        speed = float(np.linalg.norm(self.trace.velocities[index]))
        torque_magnitude = float(np.linalg.norm(self.trace.total_torque[index]))
        self.axes.set_title(
            "Synthetic flight presentation prototype"
            f" | t={time_s:.2f} s | speed={speed:.1f} demo units/s"
            f" | |torque|={torque_magnitude:.1f} demo units"
        )
        self.figure.canvas.draw_idle()


def main() -> None:
    """Launch the synthetic presentation; CSV parsing is deliberately deferred."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--samples",
        type=int,
        default=320,
        help="number of synthetic poses to generate",
    )
    args = parser.parse_args()
    if args.samples < 2:
        parser.error("--samples must be at least 2")

    presentation = FlightPresentation(make_demo_trace(sample_count=args.samples))
    presentation.figure.canvas.draw()
    plt.show()


if __name__ == "__main__":
    main()
