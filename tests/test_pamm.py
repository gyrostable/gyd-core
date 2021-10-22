import pytest

from tests.support.constants import XU_MAX_REL, ALPHA_MIN_REL, THETA_FLOOR
from tests.support.utils import scale, truncate

# State:
# uint256 redemptionLevel; // x
# uint256 totalGyroSupply; // y
# uint256 reserveValue; // b


class Region:
    CASE_i = 0
    CASE_I_ii = 1
    CASE_I_iii = 2
    CASE_II_H = 3
    CASE_II_L = 4
    CASE_III_H = 5
    CASE_III_L = 6


def scale_args(args):
    return [scale(a) for a in args]


def test_params(pamm):
    (
        decay_slope_lower_bound,
        stable_redeem_threshold_upper_bound,
        target_reserve_ratio_floor,
    ) = pamm.systemParams()
    assert decay_slope_lower_bound == ALPHA_MIN_REL
    assert stable_redeem_threshold_upper_bound == XU_MAX_REL
    assert target_reserve_ratio_floor == THETA_FLOOR


def test_compute_derived_params(pamm):
    (
        reserve_value_threshold_first_region,
        reserve_value_threshold_second_region,
        lower_redemption_threshold,
        reserve_high_low_threshold,
        last_region_high_low_threshold,
        upper_bound_redemption_threshold,
        slope_threshold,
    ) = pamm.computeDerivedParams()
    assert reserve_value_threshold_first_region == scale("0.8")
    assert reserve_value_threshold_second_region == scale("0.68")
    assert lower_redemption_threshold == scale("0.7")
    assert reserve_high_low_threshold == scale("0.92")
    assert upper_bound_redemption_threshold == scale("0.3")
    assert last_region_high_low_threshold == scale("0.8")
    assert slope_threshold == scale("1")

    pamm.setDecaySlopeLowerBound(scale("0.3"))
    (
        reserve_value_threshold_first_region,
        reserve_value_threshold_second_region,
        lower_redemption_threshold,
        reserve_high_low_threshold,
        last_region_high_low_threshold,
        upper_bound_redemption_threshold,
        slope_threshold,
    ) = pamm.computeDerivedParams()
    assert reserve_value_threshold_first_region == scale("0.9265")
    assert reserve_value_threshold_second_region == scale("0.85")
    assert lower_redemption_threshold == scale("1")
    assert truncate(reserve_high_low_threshold) == scale("0.73333")
    assert upper_bound_redemption_threshold == scale("0")
    assert last_region_high_low_threshold == scale("0.8")
    assert slope_threshold == scale("0.4")


def test_compute_fixed_reserve(pamm):
    cases = [
        (("0.3", "0.8", "1", "1.0", "0.3", "0.7"), "0.5"),
        (("0.4", "0.8775", "1", "0.5", "0.3", "1"), "0.48"),
        (("0.4", "0.85", "1", "0.5", "0.22", "0.9"), "0.4581"),
    ]
    for args, expected in cases:
        result = pamm.testComputeFixedReserve(*scale_args(args))
        assert result == scale(expected)


def test_compute_upper_redemption_threshold(pamm):
    cases = [
        (("0.85", "1", "0.5", "0.3"), "0.2254"),
        (("0.85", "1", "0.3", "0.3"), "0"),
    ]
    for args, expected in cases:
        args = scale_args(args) + [scale(1) - THETA_FLOOR]
        result = pamm.testComputeUpperRedemptionThreshold(*args)
        assert truncate(result, precision=4) == scale(expected)


def test_compute_slope(pamm):
    cases = [
        (("0.8", "1", "0.6", "0.5"), "0.5"),
        (("0.85", "1", "0.6", "0.5"), "0.5"),
        (("0.8", "1", "0.6", "0.1"), "0.4"),
        (("0.85", "1", "0.6", "0.1"), "0.3"),
    ]
    for args, expected in cases:
        result = pamm.testComputeSlope(*scale_args(args))
        assert result == scale(expected)


def test_compute_reserve(pamm):
    cases = [
        (("0.4", "0.85", "1"), "0.5", "0.45762"),
        (("0.7", "0.85", "1"), "0.3", "0.2235"),
    ]
    for args, alpha_min, expected in cases:
        args = scale_args(args) + [(scale(alpha_min), XU_MAX_REL, THETA_FLOOR)]
        result = pamm.testComputeReserve(*args)
        assert truncate(result) == scale(expected)


def test_compute_region(pamm):
    cases = [
        (("0.1", "0.8", 1), "1", Region.CASE_i),
        (("0.1", "0.61", 1), "1", Region.CASE_III_L),
        (("0.3", "0.7", 1), "1", Region.CASE_II_L),
        (("0.8", "0.9", 1), "1", Region.CASE_I_iii),
        (("0.1", "0.75", 1), "1", Region.CASE_i),
        (("0.2", "0.75", 1), "1", Region.CASE_II_L),
        (("0.4", "0.85", 1), "0.5", Region.CASE_II_H),
        (("0.7", "0.85", 1), "0.3", Region.CASE_II_H),
        (("0.7", "0.8499", 1), "0.3", Region.CASE_III_H),
        (("0.7", "0.8501", 1), "0.3", Region.CASE_II_H),
        (("0.2", "0.65", 1), "0.3", Region.CASE_III_L),
    ]
    for state, alpha_min, expected_region in cases:
        pamm.setDecaySlopeLowerBound(scale(alpha_min))
        computed_region = pamm.computeRegion(scale_args(state))
        assert computed_region == expected_region


def test_compute_reserve_value(pamm):
    cases = [
        (("0.8", "0.9", "1"), "1", 0.9),  # TODO: check precision error
        (("0.1", "0.75", "1"), "1", 0.75),
        (("0.2", "0.75", "1"), "1", 0.75),
        (("0.4", "0.85", "1"), "0.5", 0.85),  # TODO: check precision error
        (("0.7", "0.8499", "1"), "0.5", 0.8499),  # TODO: check precision error
        (("0.7", "0.8501", "1"), "0.5", 0.8501),  # TODO: check precision error
        (("0.2", "0.65", "1"), "1", 0.65),
        (("0.7", "0.85", "1"), "0.3", 0.85),
        (("0.7", "0.8499", "1"), "0.3", 0.8499),
        (("0.7", "0.8501", "1"), "0.3", 0.8501),  # TODO: check precision error
    ]
    for state, alpha_min, expected_reserve in cases:
        pamm.setDecaySlopeLowerBound(scale(alpha_min))
        computed_reserve = pamm.computeReserveValue(scale_args(state))
        assert computed_reserve / 10 ** 18 == pytest.approx(expected_reserve)
