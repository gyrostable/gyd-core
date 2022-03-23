from typing import Iterable
from math import pi, sin, cos
import hypothesis.strategies as st
from brownie.test import given
from hypothesis import assume
import lp_share_pricing as math_implementation
from tests.support.utils_pools import scale, to_decimal, qdecimals
from tests.support.types import *
from tests.support.quantized_decimal import QuantizedDecimal as D
import tests.support.cpmmv2.math_implementation as gyro_2_math_implementation
import tests.support.cemm.mimpl as mimpl


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


@st.composite
def gen_params_CPMM(draw, n: int):
    balances = draw(gen_balances(n))
    supply = draw(
        qdecimals(D("1e-1").raw * max(balances), D("1e4").raw * max(balances))
    )

    return [balances, supply]


@st.composite
def gen_balances(draw, n: int):
    balances = [draw(billion_balance_strategy) for _ in range(n)]

    for i in range(n):
        for j in range(n):
            assume(balances[j] > 0)
            assume(balances[i] / balances[j] > 0.0001)

    return balances


######################################################################
### Test the CPMM
######################################################################


@given(
    weight=weights_strategy,
    params=gen_params_CPMM(2),
)
def test_compare_price_bpt_cpmm_2(
    gyro_lp_price_testing,
    params,
    weight,
):
    balances = params[0]
    supply = params[1]

    weights = (weight, D(1) - weight)
    invariant = D(balances[0]) ** weights[0] * D(balances[1]) ** weights[1]
    invariant_div_supply = invariant / supply
    # Let the second asset be the numeraire
    underlying_prices = [D(balances[1] / balances[0]), D(1)]

    bpt_price_sol = gyro_lp_price_testing.priceBptTwoAssetCPMM(
        scale(weights), scale(invariant_div_supply), scale(underlying_prices)
    )

    calculated_price = (
        D(underlying_prices[0]) * balances[0] + D(underlying_prices[1]) * balances[1]
    ) / supply

    assert D(bpt_price_sol) == scale(calculated_price).approxed(rel=D("1e-4"))


@given(
    rand=st.tuples(weights_strategy, weights_strategy),
    params=gen_params_CPMM(3),
)
def test_compare_price_bpt_cpmm_3(gyro_lp_price_testing, rand, params):
    balances = params[0]
    supply = params[1]

    weights = tuple(get_uniform_samples(list(rand)))
    if check_weights_invalid(weights):
        return

    invariant = (
        D(balances[0]) ** weights[0]
        * D(balances[1]) ** weights[1]
        * D(balances[2]) ** weights[2]
    )
    invariant_div_supply = invariant / supply

    # Let the third asset be the numeraire
    underlying_prices = [
        D(balances[2] / balances[0]),
        D(balances[2] / balances[1]),
        D(1),
    ]

    bpt_price_sol = gyro_lp_price_testing.priceBptCPMM(
        scale(weights), scale(invariant_div_supply), scale(underlying_prices)
    )

    calculated_price = (
        underlying_prices[0] * balances[0]
        + underlying_prices[1] * balances[1]
        + underlying_prices[2] * balances[2]
    ) / supply

    assert to_decimal(bpt_price_sol) == scale(calculated_price).approxed(rel=D("1"))


@given(
    rand=st.tuples(weights_strategy, weights_strategy, weights_strategy),
    params=gen_params_CPMM(4),
)
def test_compare_price_bpt_cpmm_4(gyro_lp_price_testing, rand, params):
    balances = params[0]
    supply = params[1]

    weights = tuple(get_uniform_samples(list(rand)))
    if check_weights_invalid(weights):
        return

    invariant = (
        D(balances[0]) ** weights[0]
        * D(balances[1]) ** weights[1]
        * D(balances[2]) ** weights[2]
        * D(balances[3]) ** weights[3]
    )
    invariant_div_supply = invariant / supply

    # Let the fourth asset be the numeraire
    underlying_prices = [
        D(balances[3] / balances[0]),
        D(balances[3] / balances[1]),
        D(balances[3] / balances[2]),
        D(1),
    ]

    bpt_price_sol = gyro_lp_price_testing.priceBptCPMM(
        scale(weights), scale(invariant_div_supply), scale(underlying_prices)
    )

    calculated_price = (
        underlying_prices[0] * balances[0]
        + underlying_prices[1] * balances[1]
        + underlying_prices[2] * balances[2]
        + underlying_prices[3] * balances[3]
    ) / supply

    assert to_decimal(bpt_price_sol) == scale(calculated_price).approxed(rel=D("1"))


######################################################################
### Test the CPMM Equal Weights
######################################################################


@given(
    params=gen_params_CPMM(2),
)
def test_compare_price_bpt_cpmm_equal_weights_2(gyro_lp_price_testing, params):
    balances = params[0]
    supply = params[1]
    weight = D(1 / 2)
    invariant = D(balances[0]) ** weight * D(balances[1]) ** weight
    invariant_div_supply = invariant / supply
    # Let the second asset be the numeraire
    underlying_prices = [D(balances[1] / balances[0]), D(1)]

    bpt_price_sol = gyro_lp_price_testing.priceBptCPMMEqualWeights(
        scale(weight), scale(invariant_div_supply), scale(underlying_prices)
    )

    calculated_price = (
        underlying_prices[0] * balances[0] + underlying_prices[1] * balances[1]
    ) / supply

    assert to_decimal(bpt_price_sol) == scale(calculated_price).approxed(rel=D("1"))


@given(
    params=gen_params_CPMM(3),
)
def test_compare_price_bpt_cpmm_equal_weights_3(
    gyro_lp_price_testing,
    params,
):
    balances = params[0]
    supply = params[1]
    weight = D(1 / 3)
    invariant = D(balances[0]) ** weight * D(balances[1]) ** weight
    invariant_div_supply = invariant / supply

    # Let the third asset be the numeraire
    underlying_prices = [
        D(balances[2] / balances[0]),
        D(balances[2] / balances[1]),
        D(1),
    ]

    bpt_price_sol = gyro_lp_price_testing.priceBptCPMMEqualWeights(
        scale(weight), scale(invariant_div_supply), scale(underlying_prices)
    )

    calculated_price = (
        underlying_prices[0] * balances[0]
        + underlying_prices[1] * balances[1]
        + underlying_prices[2] * balances[2]
    ) / supply

    assert to_decimal(bpt_price_sol) == scale(calculated_price).approxed(rel=D("1"))


@given(
    params=gen_params_CPMM(4),
)
def test_compare_price_bpt_cpmm_equal_weights_4(gyro_lp_price_testing, params):
    balances = params[0]
    supply = params[1]
    weight = D(1 / 4)
    invariant = D(balances[0]) ** weight * D(balances[1]) ** weight
    invariant_div_supply = invariant / supply

    # Let the fourth asset be the numeraire
    underlying_prices = [
        D(balances[3] / balances[0]),
        D(balances[3] / balances[1]),
        D(balances[3] / balances[2]),
        D(1),
    ]
    bpt_price_sol = gyro_lp_price_testing.priceBptCPMMEqualWeights(
        scale(weight), scale(invariant_div_supply), scale(underlying_prices)
    )

    calculated_price = (
        underlying_prices[0] * balances[0]
        + underlying_prices[1] * balances[1]
        + underlying_prices[2] * balances[2]
        + underlying_prices[3] * balances[3]
    ) / supply

    assert to_decimal(bpt_price_sol) == scale(calculated_price).approxed(rel=D("1"))


######################################################################
### Test the CPMMv2

# this is a multiplicative separation
# This is consistent with tightest price range of 0.9999 - 1.0001
######################################################################

MIN_SQRTPARAM_SEPARATION = to_decimal("1.0001")


def faulty_params_cpmmv2(sqrt_alpha, sqrt_beta):
    return sqrt_beta <= sqrt_alpha * MIN_SQRTPARAM_SEPARATION


@given(
    sqrt_alpha=st.decimals(min_value="0.02", max_value="0.99995", places=4),
    sqrt_beta=st.decimals(min_value="1.00005", max_value="1.8", places=4),
    params=gen_params_CPMM(2),
)
def test_compare_price_bpt_cpmmv2(
    gyro_lp_price_testing,
    sqrt_alpha,
    sqrt_beta,
    params,
):
    balances = params[0]
    supply = params[1]

    if faulty_params_cpmmv2(sqrt_alpha, sqrt_beta):
        return

    print(gyro_2_math_implementation)
    invariant = gyro_2_math_implementation.calculateInvariant(
        balances, D(sqrt_alpha), D(sqrt_beta)
    )
    invariant_div_supply = invariant / supply

    virtual_parameter_0 = gyro_2_math_implementation.calculateVirtualParameter0(
        invariant, D(sqrt_beta)
    )

    virtual_parameter_1 = gyro_2_math_implementation.calculateVirtualParameter1(
        invariant, D(sqrt_alpha)
    )

    # Let the second asset be the numeraire
    underlying_prices = [
        D(balances[1] + virtual_parameter_1 / balances[0] + virtual_parameter_0),
        D(1),
    ]

    bpt_price_sol = gyro_lp_price_testing.priceBptCPMMv2(
        scale(sqrt_alpha),
        scale(sqrt_beta),
        scale(invariant_div_supply),
        scale(underlying_prices),
    )

    calculated_price = (
        underlying_prices[0] * balances[0] + underlying_prices[1] * balances[1]
    ) / supply

    assert to_decimal(bpt_price_sol) == scale(calculated_price).approxed(rel=D("1"))


# ######################################################################
# ### Test the CEMM
# ######################################################################

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


def params2MathParams(params: CEMMMathParams) -> mimpl.Params:
    """The python math implementation is a bit older and uses its own data structures. This function converts."""
    return mimpl.Params(params.alpha, params.beta, params.c, -params.s, params.lam)


def get_derived_parameters(params):
    mparams = params2MathParams(params)
    derived = CEMMMathDerivedParams(
        Vector2(mparams.tau_alpha[0], mparams.tau_alpha[1]),
        Vector2(mparams.tau_beta[0], mparams.tau_beta[1]),
    )
    return scale(derived)


def calculate_invariant_cemm(
    params,
    balances,
):
    mparams = params2MathParams(params)
    cemm = mimpl.CEMM.from_x_y(balances[0], balances[1], mparams)
    return cemm.r


def calculate_price_cemm(
    params,
    balances,
):
    assume(balances != (0, 0))
    mparams = params2MathParams(params)
    cemm = mimpl.CEMM.from_x_y(balances[0], balances[1], mparams)

    return cemm.px


@given(
    params=gen_params(),
    other_params=gen_params_CPMM(2),
)
def test_compare_price_bpt_cemm(
    gyro_lp_price_testing, params: CEMMMathParams, other_params
):
    balances = other_params[0]
    supply = other_params[1]

    invariant = calculate_invariant_cemm(params, balances)
    invariant_div_supply = invariant / D(supply)

    underlying_prices = [calculate_price_cemm(params, balances), D(1)]

    if faulty_params_cemm(params):
        return

    derived = mk_derived_params(params)

    bpt_price_sol = gyro_lp_price_testing.priceBptCEMM(
        scale(params),
        scale(derived),
        scale(invariant_div_supply),
        scale(underlying_prices),
    )

    calculated_price = (
        underlying_prices[0] * balances[0] + underlying_prices[1] * balances[1]
    ) / supply

    assert to_decimal(bpt_price_sol) == scale(calculated_price).approxed(rel=D("1e-4"))
