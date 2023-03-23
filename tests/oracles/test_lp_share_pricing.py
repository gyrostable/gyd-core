import functools
from decimal import Decimal
from math import cos, pi, sin, tan
from pickle import FALSE
from typing import Iterable, Tuple

import hypothesis.strategies as st
from _pytest.python_api import ApproxDecimal
from brownie import reverts, history
from brownie.exceptions import VirtualMachineError
from brownie.test import given
from hypothesis import assume, note, settings, example
from tests.support.quantized_decimal import QuantizedDecimal as D
from tests.support.types import *
from tests.support.utils_pools import qdecimals, scale, to_decimal, unscale

import lp_share_pricing as math_implementation

MIN_PRICE = "1e-6"
MAX_PRICE = "1e6"
MIN_PRICE_SEPARATION = D("0.001")

billion_balance_strategy = st.integers(min_value=0, max_value=1_000_000_000)
weights_strategy = st.decimals(min_value="0.05", max_value="0.95")
price_strategy = st.decimals(min_value=MIN_PRICE, max_value=MAX_PRICE)
price_strategy_less_extreme = st.decimals(min_value="1e-4", max_value="1e6")


# takes argument a list of n-1 numbers in [0,1], outputs n-tuple, uniformly distributed, that sums to 1
def get_uniform_samples(lst: Iterable[D]):
    lst = sorted(lst + [D(0), D(1)])
    return [D(to_decimal(lst[i + 1] - lst[i])) for i in range(len(lst) - 1)]


def check_weights_invalid(weights: Iterable[D]):
    for i in range(len(weights)):
        if weights[i] < 0.05 or weights[i] > 0.95:
            return True
    else:
        return False


######################################################################
### Test the CPMM
@given(
    invariant_div_supply=st.decimals(min_value="0.5", max_value="100000000", places=4),
    weight=weights_strategy,
    underlying_prices=st.tuples(
        price_strategy_less_extreme, price_strategy_less_extreme
    ),
)
def test_price_bpt_cpmm_2(
    gyro_lp_price_testing, weight, invariant_div_supply, underlying_prices
):
    weights = (weight, D(1) - weight)
    bpt_price_sol = gyro_lp_price_testing.priceBptTwoAssetCPMM(
        scale(weights), scale(invariant_div_supply), scale(underlying_prices)
    )

    bpt_price = math_implementation.price_bpt_two_asset_CPMM(
        weights, invariant_div_supply, underlying_prices
    )

    assert to_decimal(bpt_price_sol) == scale(bpt_price).approxed()


@given(
    invariant_div_supply=st.decimals(min_value="0.5", max_value="100000000", places=4),
    rand=st.tuples(weights_strategy, weights_strategy),
    underlying_prices=st.tuples(price_strategy, price_strategy, price_strategy),
)
def test_price_bpt_cpmm_3(
    gyro_lp_price_testing, rand, invariant_div_supply, underlying_prices
):
    weights = tuple(get_uniform_samples(list(rand)))
    assume(not check_weights_invalid(weights))

    bpt_price_sol = gyro_lp_price_testing.priceBptCPMM(
        scale(weights), scale(invariant_div_supply), scale(underlying_prices)
    )

    bpt_price = math_implementation.price_bpt_CPMM(
        weights, invariant_div_supply, underlying_prices
    )

    assert to_decimal(bpt_price_sol) == scale(bpt_price).approxed()


@given(
    invariant_div_supply=st.decimals(min_value="0.5", max_value="100000000", places=4),
    rand=st.tuples(weights_strategy, weights_strategy, weights_strategy),
    underlying_prices=st.tuples(
        price_strategy, price_strategy, price_strategy, price_strategy
    ),
)
def test_price_bpt_cpmm_4(
    gyro_lp_price_testing, rand, invariant_div_supply, underlying_prices
):
    weights = tuple(get_uniform_samples(list(rand)))
    assume(not check_weights_invalid(weights))

    bpt_price_sol = gyro_lp_price_testing.priceBptCPMM(
        scale(weights), scale(invariant_div_supply), scale(underlying_prices)
    )

    bpt_price = math_implementation.price_bpt_CPMM(
        weights, invariant_div_supply, underlying_prices
    )

    assert to_decimal(bpt_price_sol) == scale(bpt_price).approxed()


######################################################################
### Test the CPMM Equal Weights
@given(
    invariant_div_supply=st.decimals(min_value="0.5", max_value="100000000", places=4),
    underlying_prices=st.tuples(price_strategy, price_strategy),
)
def test_price_bpt_cpmm_equal_weights_2(
    gyro_lp_price_testing, invariant_div_supply, underlying_prices
):
    weight = D(1 / 2)
    bpt_price_sol = gyro_lp_price_testing.priceBptCPMMEqualWeights(
        scale(weight), scale(invariant_div_supply), scale(underlying_prices)
    )

    bpt_price = math_implementation.price_bpt_CPMM_equal_weights(
        weight, invariant_div_supply, underlying_prices
    )

    assert to_decimal(bpt_price_sol) == scale(bpt_price).approxed()


@given(
    invariant_div_supply=st.decimals(min_value="0.5", max_value="100000000", places=4),
    underlying_prices=st.tuples(
        price_strategy_less_extreme,
        price_strategy_less_extreme,
        price_strategy_less_extreme,
    ),
)
def test_price_bpt_cpmm_equal_weights_3(
    gyro_lp_price_testing, invariant_div_supply, underlying_prices
):
    weight = D(1 / 3)
    bpt_price_sol = gyro_lp_price_testing.priceBptCPMMEqualWeights(
        scale(weight), scale(invariant_div_supply), scale(underlying_prices)
    )

    bpt_price = math_implementation.price_bpt_CPMM_equal_weights(
        weight, invariant_div_supply, underlying_prices
    )

    assert to_decimal(bpt_price_sol) == scale(bpt_price).approxed()


@given(
    invariant_div_supply=st.decimals(min_value="0.5", max_value="100000000", places=4),
    underlying_prices=st.tuples(
        price_strategy_less_extreme,
        price_strategy_less_extreme,
        price_strategy_less_extreme,
        price_strategy_less_extreme,
    ),
)
def test_price_bpt_cpmm_equal_weights_4(
    gyro_lp_price_testing, invariant_div_supply, underlying_prices
):
    weight = D(1 / 4)
    bpt_price_sol = gyro_lp_price_testing.priceBptCPMMEqualWeights(
        scale(weight), scale(invariant_div_supply), scale(underlying_prices)
    )

    bpt_price = math_implementation.price_bpt_CPMM_equal_weights(
        weight, invariant_div_supply, underlying_prices
    )

    assert int(bpt_price_sol) == scale(bpt_price).approxed(rel=D("10") ** -4)


######################################################################
### Test the 2CLP

# this is a multiplicative separation
# This is consistent with tightest price range of 0.9999 - 1.0001
MIN_SQRTPARAM_SEPARATION = to_decimal("1.0001")


def faulty_params_2CLP(sqrt_alpha, sqrt_beta):
    return sqrt_beta <= sqrt_alpha * MIN_SQRTPARAM_SEPARATION


@given(
    sqrt_alpha=st.decimals(min_value="0.02", max_value="0.99995", places=4),
    sqrt_beta=st.decimals(min_value="1.00005", max_value="1.8", places=4),
    invariant_div_supply=st.decimals(min_value="0.5", max_value="100000000", places=4),
    underlying_prices=st.tuples(price_strategy, price_strategy),
)
def test_price_bpt_2CLP(
    gyro_lp_price_testing,
    sqrt_alpha,
    sqrt_beta,
    invariant_div_supply,
    underlying_prices,
):
    assume(not faulty_params_2CLP(sqrt_alpha, sqrt_beta))

    bpt_price_sol = gyro_lp_price_testing.priceBpt2CLP(
        scale(sqrt_alpha),
        scale(sqrt_beta),
        scale(invariant_div_supply),
        scale(underlying_prices),
    )

    bpt_price = math_implementation.price_bpt_2clp(
        sqrt_alpha, sqrt_beta, invariant_div_supply, underlying_prices
    )

    assert to_decimal(bpt_price_sol) == scale(bpt_price).approxed()


######################################################################
### Test the 3CLP

ROOT_ALPHA_MAX = "0.99996666555"
ROOT_ALPHA_MIN = "0.2"


def gen_root3Alpha():
    return qdecimals(min_value=ROOT_ALPHA_MIN, max_value=ROOT_ALPHA_MAX, places=4)


def gen_three_prices(min_price=MIN_PRICE, max_price=MAX_PRICE):
    return st.tuples(*([qdecimals(min_price, max_price)] * 3))


# Consistency check equilibrium prices
@settings(max_examples=200)
@given(
    root3Alpha=gen_root3Alpha(),
    underlying_prices=gen_three_prices("1e-4", "1e4"),
)
def test_python_equilibrium_prices_3CLP(root3Alpha, underlying_prices):
    alpha = root3Alpha**3

    px, py, pz = underlying_prices
    pxz = px / pz
    pyz = py / pz

    pxzPool, pyzPool = math_implementation.relativeEquilibriumPrices3CLP(
        alpha, pxz, pyz
    )

    note(f"alpha = {alpha!r}")
    note(f"pxz     = {pxz!r}")
    note(f"pyz     = {pyz!r}")
    note(f"pxzPool = {pxzPool!r}")
    note(f"pyzPool = {pyzPool!r}")

    prec = dict(abs=D("1e-6"), rel=D("1e-6"))

    # Test no-arbitrage conditions.
    # Note that "x > y.approxed()" is defined as "x is significantly greater than y".
    if pyzPool / pxzPool**2 > alpha.approxed(**prec):
        assert pxzPool >= pxz.approxed(**prec)
        assert pxzPool / pyzPool >= (pxz / pyz).approxed(**prec)
    if pxzPool / pyzPool**2 > alpha.approxed(**prec):
        assert pyzPool >= pyz.approxed(**prec)
        assert pxzPool / pyzPool <= (pxz / pyz).approxed(**prec)
    if pxzPool * pyzPool > alpha.approxed(**prec):
        assert pxzPool <= pxz.approxed(**prec)
        assert pyzPool <= pyz.approxed(**prec)


@given(
    root3Alpha=gen_root3Alpha(),
    underlying_prices=gen_three_prices("1e-4", "1e4"),
)
def test_equilibrium_prices_match_3CLP(
    root3Alpha, underlying_prices, gyro_lp_price_testing
):
    alpha = root3Alpha**3

    px, py, pz = underlying_prices
    pxz = px / pz
    pyz = py / pz

    pxzPool_math, pyzPool_math = math_implementation.relativeEquilibriumPrices3CLP(
        alpha, pxz, pyz
    )

    pxzPool_sol, pyzPool_sol = unscale(
        gyro_lp_price_testing.relativeEquilibriumPrices3CLP(
            scale(alpha), scale(pxz), scale(pyz)
        )
    )

    note(f"alpha = {alpha!r}")
    note(f"pxz          = {pxz!r}")
    note(f"pyz          = {pyz!r}")
    note(f"pxzPool_math = {pxzPool_math!r}")
    note(f"pxzPool_sol  = {pxzPool_sol!r}")
    note(f"pyzPool_math = {pyzPool_math!r}")
    note(f"pyzPool_sol  = {pyzPool_sol!r}")

    prec = dict(abs=D("1e-9"), rel=D("1e-9"))
    assert pxzPool_sol == pxzPool_math.approxed(**prec)
    assert pyzPool_sol == pyzPool_math.approxed(**prec)


@given(
    root3Alpha=gen_root3Alpha(),
    invariant_div_supply=qdecimals(min_value="0.5", max_value="100000000", places=4),
    underlying_prices=gen_three_prices("1e-4", "1e4"),
)
def test_price_bpt_match_3CLP(
    root3Alpha, invariant_div_supply, underlying_prices, gyro_lp_price_testing
):
    bpt_price_math = math_implementation.price_bpt_3CLP(
        root3Alpha, invariant_div_supply, underlying_prices
    )

    bpt_price_sol = unscale(
        gyro_lp_price_testing.priceBpt3CLP(
            scale(root3Alpha), scale(invariant_div_supply), scale(underlying_prices)
        )
    )

    note(f"bpt_price_math = {bpt_price_math!r}")
    note(f"bpt_price_sol  = {bpt_price_sol!r}")

    # FIXME: this fails with lower relative error
    assert bpt_price_sol == bpt_price_math.approxed(abs=D("1e-3"), rel=D("1e-3"))


######################################################################
### Test the ECLP

# This is consistent with tightest price range of beta - alpha >= MIN_PRICE_SEPARATION
ECLP_MIN_PRICE_SEPARATION = to_decimal("0.0001")


@st.composite
def gen_params(draw):
    phi_degrees = draw(st.floats(10, 80))
    phi = phi_degrees / 360 * 2 * pi

    # Price bounds. Choose s.t. the 'peg' lies within the bounds.
    # It'd be nonsensical if this was not the case: Why are we using an ellipse then?!
    peg = tan(phi)  # = price where the flattest point of the ellipse lies.
    peg = D(peg)
    alpha_high = peg
    beta_low = peg
    alpha = draw(qdecimals("0.05", alpha_high.raw))
    beta = draw(
        qdecimals(max(beta_low.raw, (alpha + MIN_PRICE_SEPARATION).raw), "20.0")
    )

    s = sin(phi)
    c = cos(phi)
    l = draw(qdecimals("1", "1e8"))
    return ECLPMathParams(alpha, beta, D(c), D(s), l)


def faulty_params_eclp(params: ECLPMathParams):
    if (
        params.beta > params.alpha
        and params.beta - params.alpha > ECLP_MIN_PRICE_SEPARATION
    ):
        return False
    else:
        return True


def mk_derived_params(params: ECLPMathParams):
    tau_alpha = math_implementation.tau(params, params.alpha)
    tau_beta = math_implementation.tau(params, params.beta)
    return ECLPMathDerivedParams(
        Vector2(tau_alpha[0], tau_alpha[1]), Vector2(tau_beta[0], tau_beta[1])
    )


@given(
    params=gen_params(),
    invariant_div_supply=st.decimals(min_value="0.5", max_value="100000000", places=4),
    underlying_prices=st.tuples(price_strategy, price_strategy),
)
def test_price_bpt_eclp(
    gyro_lp_price_testing,
    params: ECLPMathParams,
    invariant_div_supply,
    underlying_prices,
):
    assume(not faulty_params_eclp(params))

    derived = mk_derived_params(params)

    bpt_price_sol = gyro_lp_price_testing.priceBptECLP(
        scale(params),
        scale(derived) + [0] * 5,
        scale(invariant_div_supply),
        scale(underlying_prices),
    )

    mparams = math_implementation.ECLP_params(
        params.alpha, params.beta, params.c, params.s, params.lam
    )
    mderived = math_implementation.ECLP_derived_params(
        (derived.tauAlpha.x, derived.tauAlpha.y),
        (derived.tauBeta.x, derived.tauBeta.y),
    )

    bpt_price = math_implementation.price_bpt_ECLP(
        mparams, mderived, invariant_div_supply, underlying_prices
    )

    assert to_decimal(bpt_price_sol) == scale(bpt_price).approxed(rel=D("1e-10"))
