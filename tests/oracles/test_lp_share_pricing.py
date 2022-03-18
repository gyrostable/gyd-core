import functools
from decimal import Decimal
from math import pi, sin, cos
from pickle import FALSE
from typing import Tuple, Iterable

import hypothesis.strategies as st
from _pytest.python_api import ApproxDecimal
from brownie.test import given
from brownie import reverts
from hypothesis import assume, settings
import lp_share_pricing as math_implementation
from tests.support.utils_pools import scale, to_decimal, qdecimals
from tests.support.types import *
from tests.support.quantized_decimal import QuantizedDecimal as D

billion_balance_strategy = st.integers(min_value=0, max_value=1_000_000_000)
weights_strategy = st.decimals(min_value="0.05", max_value="0.95")
price_strategy = st.decimals(min_value="1e-6", max_value="1e6")
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
    underlying_prices=st.tuples(price_strategy, price_strategy),
)
def test_price_bpt_cpmm_2(
    gyro_lp_price_testing, weight, invariant_div_supply, underlying_prices
):
    weights = (weight, D(1) - weight)
    bpt_price_sol = gyro_lp_price_testing.priceBptCPMM(
        scale(weights), scale(invariant_div_supply), scale(underlying_prices)
    )

    bpt_price = math_implementation.price_bpt_CPMM(
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
    if check_weights_invalid(weights):
        return

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
    if check_weights_invalid(weights):
        return

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
### Test the CPMMv2

# this is a multiplicative separation
# This is consistent with tightest price range of 0.9999 - 1.0001
MIN_SQRTPARAM_SEPARATION = to_decimal("1.0001")


def faulty_params_cpmmv2(sqrt_alpha, sqrt_beta):
    return sqrt_beta <= sqrt_alpha * MIN_SQRTPARAM_SEPARATION


@given(
    sqrt_alpha=st.decimals(min_value="0.02", max_value="0.99995", places=4),
    sqrt_beta=st.decimals(min_value="1.00005", max_value="1.8", places=4),
    invariant_div_supply=st.decimals(min_value="0.5", max_value="100000000", places=4),
    underlying_prices=st.tuples(price_strategy, price_strategy),
)
def test_price_bpt_cpmmv2(
    gyro_lp_price_testing,
    sqrt_alpha,
    sqrt_beta,
    invariant_div_supply,
    underlying_prices,
):
    if faulty_params_cpmmv2(sqrt_alpha, sqrt_beta):
        return

    bpt_price_sol = gyro_lp_price_testing.priceBptCPMMv2(
        scale(sqrt_alpha),
        scale(sqrt_beta),
        scale(invariant_div_supply),
        scale(underlying_prices),
    )

    bpt_price = math_implementation.price_bpt_CPMMv2(
        sqrt_alpha, sqrt_beta, invariant_div_supply, underlying_prices
    )

    assert to_decimal(bpt_price_sol) == scale(bpt_price).approxed()


######################################################################
### Test the CEMM

# This is consistent with tightest price range of beta - alpha >= MIN_PRICE_SEPARATION
CEMM_MIN_PRICE_SEPARATION = to_decimal("0.0001")


@st.composite
def gen_params(draw):
    phi_degrees = draw(st.floats(10, 80))
    phi = phi_degrees / 360 * 2 * pi
    s = sin(phi)
    c = cos(phi)
    lam = draw(qdecimals("1", "10000"))
    alpha = draw(qdecimals("0.05", "0.995"))
    beta = draw(qdecimals("1.005", "20.0"))
    price_peg = draw(qdecimals("0.05", "20.0"))
    # price_peg = D(1)
    return CEMMMathParams(price_peg * alpha, price_peg * beta, D(c), D(s), lam)


def faulty_params_cemm(params: CEMMMathParams):
    if (
        params.beta > params.alpha
        and params.beta - params.alpha > CEMM_MIN_PRICE_SEPARATION
    ):
        return False
    else:
        return True


def mk_derived_params(params: CEMMMathParams):
    tau_alpha = math_implementation.tau(params, params.alpha)
    tau_beta = math_implementation.tau(params, params.beta)
    return CEMMMathDerivedParams(
        Vector2(tau_alpha[0], tau_alpha[1]), Vector2(tau_beta[0], tau_beta[1])
    )


@given(
    params=gen_params(),
    invariant_div_supply=st.decimals(min_value="0.5", max_value="100000000", places=4),
    underlying_prices=st.tuples(price_strategy, price_strategy),
)
def test_price_bpt_cemm(
    gyro_lp_price_testing,
    params: CEMMMathParams,
    invariant_div_supply,
    underlying_prices,
):
    if faulty_params_cemm(params):
        return

    derived = mk_derived_params(params)

    bpt_price_sol = gyro_lp_price_testing.priceBptCEMM(
        scale(params),
        scale(derived),
        scale(invariant_div_supply),
        scale(underlying_prices),
    )

    mparams = math_implementation.CEMM_params(
        params.alpha, params.beta, params.c, params.s, params.lam
    )
    mderived = math_implementation.CEMM_derived_params(
        (derived.tauAlpha.x, derived.tauAlpha.y),
        (derived.tauBeta.x, derived.tauBeta.y),
    )

    bpt_price = math_implementation.price_bpt_CEMM(
        mparams, mderived, invariant_div_supply, underlying_prices
    )

    assert to_decimal(bpt_price_sol) == scale(bpt_price).approxed(rel=D("1e-10"))
