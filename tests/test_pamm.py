import math
from decimal import Decimal as D
from typing import Tuple

import pytest
from brownie.exceptions import VirtualMachineError
from brownie.test import given
from hypothesis import strategies as st
from hypothesis.control import assume

import tests.support.pamm as pypamm
from tests.support.constants import (
    ALPHA_MIN_REL,
    THETA_FLOOR,
    UNSCALED_THETA_FLOOR,
    UNSCALED_XU_MAX_REL,
    XU_MAX_REL,
)
from tests.support.dfuzzy import isclose, prec_input, prec_sanity_check
from tests.support.quantized_decimal import QuantizedDecimal as QD
from tests.support.utils import scale


def st_scaled_decimals(
    min_val,
    max_val=None,
    exclusive=False,
    min_exclusive=False,
    max_exclusive=False,
    **kwargs
):
    if isinstance(min_val, QD):
        min_val = min_val.raw
    if isinstance(max_val, QD):
        max_val = max_val.raw

    strategy = st.integers(int(min_val), int(max_val), **kwargs)
    if exclusive:
        min_exclusive = True
        max_exclusive = True

    if min_val is not None and min_exclusive:
        strategy = strategy.filter(lambda x: x > min_val)
    if max_val and max_exclusive:
        strategy = strategy.filter(lambda x: x < max_val)
    return strategy


@st.composite
def st_params(draw):
    alpha_bar = draw(st_scaled_decimals(scale("0.01"), scale(1)))
    xu_bar = draw(st_scaled_decimals(scale("0.01"), scale(1), max_exclusive=True))
    theta_bar_min = int((1 - math.sqrt(2 * alpha_bar / 10 ** 18)) * 10 ** 18)
    theta_bar = draw(
        st_scaled_decimals(
            max(theta_bar_min, scale("0.01")), scale(1), max_exclusive=True
        )
    )
    return (alpha_bar, xu_bar, theta_bar)


@st.composite
def st_baya(draw, theta_floor):
    # NOTE adding some generous offsets to avoid numerical errors.
    # Unclear if these actually point to a problem.
    ya = draw(st_scaled_decimals(scale("0.01"), scale(5), min_exclusive=True))
    # We only test the interesting, open bit here
    assume(ya * theta_floor / 10 ** 18 + 10 ** 9 < ya - 10 ** 9)
    ba = draw(
        st_scaled_decimals(
            ya * theta_floor / 10 ** 18 + 10 ** 9, ya - 10 ** 9, exclusive=True
        )
    )
    return ba, ya


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


@given(st.data())
def test_path_independence(admin, TestingPAMMV1, data: st.DataObject):
    params = data.draw(st_params(), "params")
    ba, ya = data.draw(st_baya(params[2]), "ba, ya")
    x1 = data.draw(st_scaled_decimals(scale("0.001"), ya - scale("0.001")), "x1")
    x2 = data.draw(st_scaled_decimals(scale("0.001"), ya - x1), "x2")
    run_path_independence_test(admin, TestingPAMMV1, x1, x2, ba, ya, params)


def run_path_independence_test(
    admin, PAMM, x1: int, x2: int, ba: int, ya: int, params: Tuple[int, int, int]
):
    assert x1 + x2 <= ya

    pamm = admin.deploy(PAMM, params)
    pamm.setState((D(0), ba, ya))

    pamm_2step = admin.deploy(PAMM, params)
    pamm_2step.setState((D(0), ba, ya))

    # NOTE: the current input generation is slightly problematic as it generates
    # inputs that are not valid and result in integer overflows/underflow
    # we ignore these for now to at least be able to test the path independence
    # on valid inputs
    try:
        redeem_tx = pamm.redeem(x1 + x2)
        redeem1_tx = pamm_2step.redeem(x1)
        redeem2_tx = pamm_2step.redeem(x2)
    except VirtualMachineError as ex:
        if ex.revert_msg != "Integer overflow":  # type: ignore
            raise ex
        # print(ex)
        return
    # print("RUNNING PATH INDEPENDENCE TEST")

    (x, b, y) = pamm.systemState()
    (x2, b2, y2) = pamm_2step.systemState()

    # First two are trivial / sanity checks
    assert x == x2
    assert y == y2

    # These two are the actual meat (and they're also kinda equivalent):
    # values are scaled to 10^18 so we allow for some absolute error of 10^-8
    # as there might be some small differences because of root computations etc
    assert int(b) == pytest.approx(b2, abs=10 ** 10)
    assert int(redeem_tx.return_value) == pytest.approx(
        redeem1_tx.return_value + redeem2_tx.return_value, abs=10 ** 10
    )