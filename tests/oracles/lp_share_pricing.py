from operator import add, sub
from typing import Iterable

from tests.support.quantized_decimal import QuantizedDecimal as D


class ECLP_params:
    def __init__(self, alpha: D, beta: D, c: D, s: D, lam: D):
        self.alpha = alpha
        self.beta = beta
        self.c = c
        self.s = s
        self.lam = lam


class ECLP_derived_params:
    def __init__(self, tau_alpha: tuple[D, D], tau_beta: tuple[D, D]):
        self.tau_alpha = tau_alpha
        self.tau_beta = tau_beta


def price_bpt_CPMM(
    weights: Iterable[D], invariant_div_supply: D, underlying_prices: Iterable[D]
) -> D:
    prod = invariant_div_supply
    for i in range(len(weights)):
        prod = prod * (underlying_prices[i] / weights[i]) ** weights[i]
    return prod


def price_bpt_two_asset_CPMM(
    weights: Iterable[D], invariant_div_supply: D, underlying_prices: Iterable[D]
) -> D:
    second_term = (
        underlying_prices[0] * (weights[1]) / (weights[0] * underlying_prices[1])
    ) ** weights[0]
    third_term = underlying_prices[1] / weights[1]
    return invariant_div_supply * second_term * third_term


def price_bpt_CPMM_equal_weights(
    weight: D, invariant_div_supply: D, underlying_prices: Iterable[D]
) -> D:
    prod = D("1")
    for i in range(len(underlying_prices)):
        prod = prod * underlying_prices[i] / weight
    prod = prod**weight
    return prod * invariant_div_supply


def price_bpt_2clp(
    sqrt_alpha: D, sqrt_beta: D, invariant_div_supply: D, underlying_prices: Iterable[D]
) -> D:
    px, py = (underlying_prices[0], underlying_prices[1])
    if px / py <= sqrt_alpha**2:
        return invariant_div_supply * px * (D(1) / sqrt_alpha - D(1) / sqrt_beta)
    elif px / py >= sqrt_beta**2:
        return invariant_div_supply * py * (sqrt_beta - sqrt_alpha)
    else:
        term = 2 * D(px * py) ** D(1 / 2) - px / sqrt_beta - py * sqrt_alpha
        return term * invariant_div_supply


def price_bpt_3clp_representable(
    cbrt_alpha: D, invariant_div_supply: D, underlying_prices: Iterable[D]
) -> D:
    """
    LP share price *if* relative prices are representable in the pool. Otherwise wrong. For the general problem, use
    price_bpt_price_bpt_3CLP().
    """
    px, py, pz = (underlying_prices[0], underlying_prices[1], underlying_prices[2])
    term = 3 * (px * py * pz) ** D(1 / 3) - (px + py + pz) * cbrt_alpha
    return term * invariant_div_supply


def price_bpt_ECLP(
    params: ECLP_params,
    derived_params: ECLP_derived_params,
    invariant_div_supply: D,
    underlying_prices: Iterable[D],
) -> D:
    px, py = (underlying_prices[0], underlying_prices[1])
    px_in_y = px / py
    if px_in_y < params.alpha:
        bp = (
            mul_Ainv(params, derived_params.tau_beta)[0]
            - mul_Ainv(params, derived_params.tau_alpha)[0]
        )
        return bp * px * invariant_div_supply
    elif px_in_y > params.beta:
        bp = (
            mul_Ainv(params, derived_params.tau_alpha)[1]
            - mul_Ainv(params, derived_params.tau_beta)[1]
        )
        return bp * py * invariant_div_supply
    else:
        sub_vec = mul_Ainv(params, tau(params, px_in_y))
        vecx = mul_Ainv(params, derived_params.tau_beta)[0] - sub_vec[0]
        vecy = mul_Ainv(params, derived_params.tau_alpha)[1] - sub_vec[1]
        return scalar_prod((px, py), (vecx, vecy)) * invariant_div_supply


def scalar_prod(t1: tuple[D, D], t2: tuple[D, D]) -> D:
    return t1[0] * t2[0] + t1[1] * t2[1]


def mul_Ainv(params: ECLP_params, t: tuple[D, D]) -> tuple[D, D]:
    vecx = t[0] * params.lam * params.c + t[1] * params.s
    vecy = -t[0] * params.lam * params.s + t[1] * params.c
    return (vecx, vecy)


def mul_A(params: ECLP_params, tp: tuple[D, D]) -> tuple[D, D]:
    vecx = params.c * tp[0] / params.lam - (params.s * tp[1] / params.lam)
    vecy = params.s * tp[0] + (params.c * tp[1])
    return (vecx, vecy)


def zeta(params: ECLP_params, px: D) -> D:
    nd = mul_A(params, (-1, px))
    return -nd[1] / nd[0]


def tau(params: ECLP_params, px: D) -> tuple[D, D]:
    return eta(zeta(params, px))


def eta(pxc: D) -> tuple[D, D]:
    z = D(1 + pxc**2) ** D(1 / 2)
    vecx = pxc / z
    vecy = D(1) / z
    return (vecx, vecy)


def relativeEquilibriumPrices3CLP(alpha: D, pXZ: D, pYZ: D) -> tuple[D, D]:
    beta = D(1) / alpha

    if pYZ <= alpha * (pXZ**2):
        if pYZ <= alpha:
            return D(1), alpha
        elif pYZ >= beta:
            return beta, beta
        else:
            return (beta * pYZ).sqrt(), pYZ
    elif pXZ <= alpha * (pYZ**2):
        if pXZ <= alpha:
            return alpha, D(1)
        elif pXZ >= beta:
            return beta, beta
        else:
            return pXZ, (beta * pXZ).sqrt()
    elif pXZ * pYZ <= alpha:
        if pXZ <= alpha * pYZ:
            return alpha, D(1)
        elif pXZ >= beta * pYZ:
            return D(1), alpha
        else:
            sqrtAlpha = alpha.sqrt()
            sqrtPXY = (pXZ / pYZ).sqrt()
            return sqrtAlpha * sqrtPXY, sqrtAlpha / sqrtPXY
    else:
        return pXZ, pYZ


def price_bpt_3CLP(
    root3Alpha: D, invariant_div_supply: D, underlying_prices: Iterable[D]
) -> D:
    alpha = root3Alpha**3

    # Relative external (actual) prices
    pXZ = underlying_prices[0] / underlying_prices[2]
    pYZ = underlying_prices[1] / underlying_prices[2]

    # Relative prices of a pool that is arbitrage-free with the external market
    pXZPool, pYZPool = relativeEquilibriumPrices3CLP(alpha, pXZ, pYZ)

    gamma = (pXZPool * pYZPool) ** (D(1) / 3)

    # Absolute prices (short notation)
    px, py, pz = underlying_prices

    value_factor = gamma * (px / pXZPool + py / pYZPool + pz) - root3Alpha * (
        px + py + pz
    )

    return invariant_div_supply * value_factor
