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

from collections.abc import Iterator

import matplotlib.pyplot as plt
import numpy as np
import pytest

from flight_trace_viewer.app import FlightPresentation
from flight_trace_viewer.app import make_demo_trace
from flight_trace_viewer.app import rotation_matrix
from flight_trace_viewer.app import torque_arc


@pytest.fixture
def presentation() -> Iterator[FlightPresentation]:
    viewer = FlightPresentation(make_demo_trace(sample_count=12))
    try:
        viewer.figure.canvas.draw()
        yield viewer
    finally:
        plt.close(viewer.figure)


def test_identity_pose_preserves_demo_axes() -> None:
    np.testing.assert_allclose(rotation_matrix(0.0, 0.0, 0.0), np.eye(3))


def test_rotation_is_orthonormal_and_preserves_handedness() -> None:
    rotation = rotation_matrix(0.7, -0.2, 0.4)

    np.testing.assert_allclose(rotation @ rotation.T, np.eye(3), atol=1e-12)
    assert np.linalg.det(rotation) == pytest.approx(1.0)


def test_positive_pitch_points_nose_up() -> None:
    rotation = rotation_matrix(0.0, 0.3, 0.0)

    assert (rotation @ np.array((1.0, 0.0, 0.0)))[2] > 0.0


def test_demo_trace_contains_finite_state_and_surface_vectors() -> None:
    trace = make_demo_trace(sample_count=32)

    assert trace.positions.shape == (32, 3)
    assert trace.surface_positions.shape == (32, 4, 3)
    assert trace.surface_lift.shape == (32, 4, 3)
    for values in (
        trace.positions,
        trace.velocities,
        trace.thrust,
        trace.aero_force,
        trace.total_torque,
    ):
        assert np.isfinite(values).all()


@pytest.mark.parametrize(
    ("torque", "expected_sign"),
    (
        ((0.0, 0.0, 1.0), 1.0),
        ((0.0, 0.0, -1.0), -1.0),
    ),
)
def test_torque_arc_winds_in_the_expected_direction(
    torque: tuple[float, float, float],
    expected_sign: float,
) -> None:
    origin = np.zeros(3)
    arc, tangent = torque_arc(origin, np.asarray(torque))
    radial = arc[0] - origin

    winding = np.dot(np.cross(radial, tangent), np.array((0.0, 0.0, 1.0)))
    assert winding * expected_sign > 0.0


def test_seek_visibility_and_rewind_controls_update_the_view(
    presentation: FlightPresentation,
) -> None:
    presentation.time_slider.set_val(float(presentation.trace.times_s[-1]))
    assert presentation.index == len(presentation.trace.times_s) - 1

    presentation.check_buttons.set_active(0)
    assert not presentation._visibility()["Aircraft velocity"]

    presentation._rewind(None)
    assert presentation.playing
    assert presentation.playback_rate < 0.0
