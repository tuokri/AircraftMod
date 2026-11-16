import pytest

from flight_trace_viewer.app import make_demo_trace
from flight_trace_viewer.plotly_renderer import _glyph_coordinates
from flight_trace_viewer.plotly_renderer import build_plotly_figure


def test_glyph_coordinates_have_segment_breaks() -> None:
    trace = make_demo_trace(sample_count=2)

    x, y, z = _glyph_coordinates(trace, 0)

    assert len(x) == len(y) == len(z) == 18
    assert x[-1] is None
    assert y[-1] is None
    assert z[-1] is None


def test_plotly_figure_contains_static_path_and_one_frame_per_pose() -> None:
    pytest.importorskip("plotly")
    trace = make_demo_trace(sample_count=4)

    figure = build_plotly_figure(trace)

    assert len(figure.data) == 2
    assert len(figure.data[0].x) == 4
    assert len(figure.frames) == 4
    assert figure.frames[0].traces == (1,)
    assert figure.frames[-1].name == "3"
    assert len(figure.layout.sliders[0].steps) == 4
    assert figure.to_json()


def test_glyph_coordinates_reject_out_of_range_frame() -> None:
    trace = make_demo_trace(sample_count=2)

    with pytest.raises(IndexError, match="frame_index out of range"):
        _glyph_coordinates(trace, 2)
