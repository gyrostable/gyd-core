from typing import Tuple
import pytest

from tests.support.constants import (
    UNSCALED_ALPHA_MIN_REL,
    UNSCALED_THETA_FLOOR,
    UNSCALED_XU_MAX_REL,
    XU_MAX_REL,
    ALPHA_MIN_REL,
    THETA_FLOOR,
)
from tests.support.quantized_decimal import QuantizedDecimal as QD
from tests.support.utils import scale, truncate
import tests.support.pamm as pypamm

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
    return tuple(scale(a) for a in args)


def qd_args(args):
    return tuple(QD(a) for a in args)


def test_params(pamm):
    (alphaBar, xuBar, thetaBar) = pamm.systemParams()
    assert alphaBar == ALPHA_MIN_REL
    assert xuBar == XU_MAX_REL
    assert thetaBar == THETA_FLOOR


@pytest.mark.parametrize("alpha_min", ["1", "0.3"])
def test_compute_derived_params(pamm, alpha_min):
    pyparams = pypamm.Params(QD(alpha_min), UNSCALED_XU_MAX_REL, UNSCALED_THETA_FLOOR)

    pamm.setDecaySlopeLowerBound(scale(alpha_min))

    (
        baThresholdRegionI,
        baThresholdRegionII,
        xlThresholdAtThresholdI,
        xlThresholdAtThresholdII,
        baThresholdIIHL,
        baThresholdIIIHL,
        xuThresholdIIHL,
        xlThresholdIIHL,
        alphaThresholdIIIHL,
        xlThresholdIIIHL,
    ) = tuple(int(v) for v in pamm.computeDerivedParams())
    assert baThresholdRegionI == scale(pyparams.ba_threshold_region_I)
    assert baThresholdRegionII == scale(pyparams.ba_threshold_region_II)
    assert xlThresholdAtThresholdI == pytest.approx(
        scale(pyparams.xl_threshold_at_threshold_I)
    )
    assert xlThresholdAtThresholdII == pytest.approx(
        scale(pyparams.xl_threshold_at_threshold_II)
    )
    assert baThresholdIIHL == scale(pyparams.ba_threshold_II_hl)
    assert xuThresholdIIHL == scale(pyparams.xu_threshold_II_hl)
    # NOTE: 1 difference, likely because of square root approximation
    assert xlThresholdIIHL == pytest.approx(scale(pyparams.xl_threshold_II_hl))
    assert baThresholdIIIHL == scale(pyparams.ba_threshold_III_hl)
    assert alphaThresholdIIIHL == scale(pyparams.slope_threshold_III_HL)
    assert xlThresholdIIIHL == scale(pyparams.xl_threshold_III_HL)


@pytest.mark.parametrize(
    "args",
    [
        ("0.3", "0.8", "1", "1.0", "0.3", "0.7"),
        ("0.4", "0.8775", "1", "0.5", "0.3", "1"),
        ("0.4", "0.85", "1", "0.5", "0.22", "0.9"),
    ],
)
def test_compute_fixed_reserve(pamm, args):
    expected = pypamm.compute_fixed_reserve(*qd_args(args))
    result = pamm.testComputeFixedReserve(*scale_args(args))
    assert result == scale(expected)


@pytest.mark.parametrize(
    "args",
    [
        ("0.85", "1", "0.5", "0.3", "0.4"),
        ("0.85", "1", "0.3", "0.3", "0.4"),
    ],
)
def test_compute_upper_redemption_threshold(pamm, args):
    expected = pypamm.compute_upper_redemption_threshold(*qd_args(args))
    result = pamm.testComputeUpperRedemptionThreshold(*scale_args(args))
    assert result == scale(expected)


@pytest.mark.parametrize(
    "args",
    [
        ("0.8", "1", "0.6", "0.5"),
        ("0.85", "1", "0.6", "0.5"),
        ("0.8", "1", "0.6", "0.1"),
        ("0.85", "1", "0.6", "0.1"),
    ],
)
def test_compute_slope(pamm, args):
    expected = pypamm.compute_slope(*qd_args(args))
    result = pamm.testComputeSlope(*scale_args(args))
    assert result == scale(expected)


@pytest.mark.parametrize(
    "args,alpha_min",
    [
        (("0.4", "0.85", "1"), "0.5"),
        (("0.7", "0.85", "1"), "0.3"),
    ],
)
def test_compute_reserve(pamm, args, alpha_min):
    pyparams = pypamm.Params(QD(alpha_min), UNSCALED_XU_MAX_REL, UNSCALED_THETA_FLOOR)
    expected = pypamm.compute_reserve(*qd_args(args), pyparams)  # type: ignore
    args = scale_args(args) + ((scale(alpha_min), XU_MAX_REL, THETA_FLOOR),)
    result = pamm.testComputeReserve(*args)
    assert result == scale(expected)


@pytest.mark.parametrize(
    "args,alpha_min",
    [
        (("0.1", "0.8", 1), "1"),  #  Region.CASE_i
        (("0.1", "0.61", 1), "1"),  #  Region.CASE_III_L
        (("0.3", "0.7", 1), "1"),  #  Region.CASE_II_L
        (("0.8", "0.9", 1), "1"),  #  Region.CASE_I_iii
        (("0.1", "0.75", 1), "1"),  #  Region.CASE_i
        (("0.2", "0.75", 1), "1"),  #  Region.CASE_II_L
        (("0.4", "0.85", 1), "0.5"),  #  Region.CASE_II_H
        (("0.7", "0.85", 1), "0.3"),  #  Region.CASE_II_H
        (("0.7", "0.8499", 1), "0.3"),  #  Region.CASE_III_H
        (("0.7", "0.8501", 1), "0.3"),  #  Region.CASE_II_H
        (("0.2", "0.65", 1), "0.3"),  #  Region.CASE_III_L
    ],
)
def test_compute_region(pamm, args, alpha_min):
    pyparams = pypamm.Params(QD(alpha_min), UNSCALED_XU_MAX_REL, UNSCALED_THETA_FLOOR)
    expected = pypamm.compute_region(*qd_args(args), pyparams)  # type: ignore
    pamm.setDecaySlopeLowerBound(scale(alpha_min))
    computed_region = pamm.computeRegion(scale_args(args))
    assert computed_region == expected.value


COMPUTE_RESERVE_CASES = [
    (("0.8", "0.9", "1"), "1"),
    (("0.1", "0.75", "1"), "1"),
    (("0.2", "0.75", "1"), "1"),
    (("0.4", "0.85", "1"), "0.5"),
    (("0.7", "0.8499", "1"), "0.5"),
    (("0.7", "0.8501", "1"), "0.5"),
    (("0.2", "0.65", "1"), "1"),
    (("0.7", "0.85", "1"), "0.3"),
    (("0.7", "0.8499", "1"), "0.3"),
    (("0.7", "0.8501", "1"), "0.3"),
]


@pytest.mark.parametrize("args,alpha_min", COMPUTE_RESERVE_CASES)
def test_compute_reserve_value(pamm, args, alpha_min):
    pyparams = pypamm.Params(QD(alpha_min), UNSCALED_XU_MAX_REL, UNSCALED_THETA_FLOOR)
    pamm_py = pypamm.Pamm(pyparams)
    x, ba, ya = qd_args(args)
    b = pypamm.compute_reserve(x, ba, ya, pyparams)
    y = ya - x
    pamm_py.update_state(x, b, y)
    expected = pamm_py._compute_normalized_anchor_reserve_value()
    assert expected is not None

    pamm.setDecaySlopeLowerBound(scale(alpha_min))
    computed_reserve = pamm.computeReserveValue(scale_args(args))
    assert computed_reserve == scale(expected)


@pytest.mark.parametrize("args,alpha_min", COMPUTE_RESERVE_CASES)
def test_compute_reserve_value_gas(pamm, args, alpha_min):
    pamm.setDecaySlopeLowerBound(scale(alpha_min))
    pamm.computeReserveValueWithGas(scale_args(args))
