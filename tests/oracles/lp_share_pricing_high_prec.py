from operator import add, sub
from typing import Iterable

from tests.support.quantized_decimal import QuantizedDecimal as D
from tests.support.quantized_decimal_100 import QuantizedDecimal as D3
from tests.support.quantized_decimal_convd import convd


class CEMM_params:
    def __init__(self, alpha: D, beta: D, c: D, s: D, lam: D):
        self.alpha = alpha
        self.beta = beta
        self.c = c
        self.s = s
        self.lam = lam


class CEMM_derived_params:
    def __init__(self, tau_alpha: tuple[D, D], tau_beta: tuple[D, D]):
        self.tau_alpha = tau_alpha
        self.tau_beta = tau_beta


def price_bpt_CPMM(
    weights: Iterable[D], invariant_div_supply: D, underlying_prices: Iterable[D]
) -> D:
    prod = convd(invariant_div_supply, D3)
    for i in range(len(weights)):
        prod = prod * (
            convd(underlying_prices[i], D3) / convd(weights[i], D3)
        ) ** convd(weights[i], D3)
    return convd(prod, D)


def price_bpt_two_asset_CPMM(
    weights: Iterable[D], invariant_div_supply: D, underlying_prices: Iterable[D]
) -> D:
    second_term = (
        (convd(underlying_prices[0], D3) * convd(weights[1], D3))
        / (convd(weights[0], D3) * convd(underlying_prices[1], D3))
    ) ** convd(weights[0], D3)
    third_term = convd(underlying_prices[1], D3) / convd(weights[1], D3)
    return convd(invariant_div_supply * second_term * third_term, D)


def price_bpt_CPMM_equal_weights(
    weight: D, invariant_div_supply: D, underlying_prices: Iterable[D]
) -> D:
    prod = D3("1")
    for i in range(len(underlying_prices)):
        prod = prod * convd(underlying_prices[i], D3) / convd(weight, D3)
    prod = prod ** convd(weight, D3)
    return convd(prod * convd(invariant_div_supply, D3), D)


def price_bpt_CPMMv2(
    sqrt_alpha: D, sqrt_beta: D, invariant_div_supply: D, underlying_prices: Iterable[D]
) -> D:
    px, py = (convd(underlying_prices[0], D3), convd(underlying_prices[1], D3))
    sqrt_alpha_high_prec = convd(sqrt_alpha, D3)
    sqrt_beta_high_prec = convd(sqrt_beta, D3)
    invariant_div_supply_high_prec = convd(invariant_div_supply, D3)

    if px / py <= sqrt_alpha_high_prec**2:
        return convd(
            (
                invariant_div_supply_high_prec
                * px
                * (D3(1) / sqrt_alpha_high_prec - D3(1) / sqrt_beta_high_prec)
            ),
            D,
        )
    elif px / py >= sqrt_beta_high_prec**2:
        return convd(
            (
                invariant_div_supply_high_prec
                * py
                * (sqrt_beta_high_prec - sqrt_alpha_high_prec)
            ),
            D,
        )
    else:
        term = (
            D3("2") * D3(px * py) ** D3(1 / 2)
            - px / sqrt_beta_high_prec
            - py * sqrt_alpha_high_prec
        )
        return convd(term * invariant_div_supply_high_prec, D)


def price_bpt_CPMMv3(
    cbrt_alpha: D, invariant_div_supply: D, underlying_prices: Iterable[D]
) -> D:
    px, py, pz = (underlying_prices[0], underlying_prices[1], underlying_prices[2])
    term = 3 * (px * py * pz) ** D(1 / 3) - (px + py + pz) * cbrt_alpha
    return term * invariant_div_supply


def price_bpt_CEMM(
    params: CEMM_params,
    derived_params: CEMM_derived_params,
    invariant_div_supply: D,
    underlying_prices: Iterable[D],
) -> D:
    invariant_div_supply_high_prec = convd(invariant_div_supply, D3)
    px, py = (convd(underlying_prices[0], D3), convd(underlying_prices[1], D3))
    px_in_y = px / py
    if px_in_y < convd(params.alpha, D3):
        bp = (
            mul_Ainv(params, derived_params.tau_beta)[0]
            - mul_Ainv(params, derived_params.tau_alpha)[0]
        )
        return convd(bp * px * invariant_div_supply_high_prec, D)
    elif px_in_y > convd(params.beta, D3):
        bp = (
            mul_Ainv(params, derived_params.tau_alpha)[1]
            - mul_Ainv(params, derived_params.tau_beta)[1]
        )
        return convd(bp * py * invariant_div_supply_high_prec, D)
    else:
        sub_vec = mul_Ainv(params, tau(params, convd(px_in_y, D)))
        vecx = mul_Ainv(params, derived_params.tau_beta)[0] - sub_vec[0]
        vecy = mul_Ainv(params, derived_params.tau_alpha)[1] - sub_vec[1]
        return convd(
            scalar_prod((px, py), (vecx, vecy)) * invariant_div_supply_high_prec, D
        )


def scalar_prod(t1: tuple[D3, D3], t2: tuple[D3, D3]) -> D3:
    return t1[0] * t2[0] + t1[1] * t2[1]


def mul_Ainv(params: CEMM_params, t: tuple[D, D]) -> tuple[D3, D3]:
    vecx = convd(t[0], D3) * convd(params.lam, D3) * convd(params.c, D3) + convd(
        t[1], D3
    ) * convd(params.s, D3)
    vecy = convd(-t[0], D3) * convd(params.lam, D3) * convd(params.s, D3) + convd(
        t[1], D3
    ) * convd(params.c, D3)
    return (vecx, vecy)


def mul_A(params: CEMM_params, tp: tuple[D, D]) -> tuple[D, D]:
    vecx = params.c * tp[0] / params.lam - (params.s * tp[1] / params.lam)
    vecy = params.s * tp[0] + (params.c * tp[1])
    return (vecx, vecy)


def zeta(params: CEMM_params, px: D) -> D:
    nd = mul_A(params, (-1, px))
    return -nd[1] / nd[0]


def tau(params: CEMM_params, px: D) -> tuple[D, D]:
    return eta(zeta(params, px))


def eta(pxc: D) -> tuple[D, D]:
    z = D(1 + pxc**2) ** D(1 / 2)
    vecx = pxc / z
    vecy = D(1) / z
    return (vecx, vecy)


def relativeEquilibriumPricesCPMMV3(alpha: D, pXZ: D, pYZ: D) -> tuple[D, D]:
    alpha_high_prec = convd(alpha, D3)
    pXZ_high_prec = convd(pXZ, D3)
    pYZ_high_prec = convd(pYZ, D3)

    # Comparisons are re-ordered vs. the write-up to increase precision.
    beta_high_prec = D3(1) / alpha_high_prec
    if pYZ_high_prec < alpha_high_prec * (pXZ_high_prec**2):
        if pYZ_high_prec < alpha_high_prec:
            return D(1), convd(alpha_high_prec, D)
        elif pYZ_high_prec > beta_high_prec:
            return convd(beta_high_prec, D), convd(beta_high_prec, D)
        else:
            return convd((beta_high_prec * pYZ_high_prec).sqrt(), D), convd(
                pYZ_high_prec, D
            )
    elif pXZ_high_prec < alpha_high_prec * (pYZ_high_prec**2):
        if pXZ_high_prec < alpha_high_prec:
            return convd(alpha_high_prec, D), D(1)
        elif pXZ_high_prec > beta_high_prec:
            return convd(beta_high_prec, D), convd(beta_high_prec, D)
        else:
            return convd(pXZ_high_prec, D), convd(
                (beta_high_prec * pXZ_high_prec).sqrt(), D
            )
    elif pXZ_high_prec * pYZ_high_prec < alpha_high_prec:
        if pXZ_high_prec < alpha_high_prec * pYZ_high_prec:
            return convd(alpha_high_prec, D), D(1)
        elif pXZ_high_prec > beta_high_prec * pYZ_high_prec:
            return D(1), convd(alpha_high_prec, D)
        else:
            return (
                convd((alpha_high_prec * pXZ_high_prec / pYZ_high_prec).sqrt(), D),
                convd((alpha_high_prec * pYZ_high_prec / pXZ_high_prec).sqrt(), D),
            )
    else:
        return convd(pXZ_high_prec, D), convd(pYZ_high_prec, D)


def price_bpt_CPMMV3(
    root3Alpha: D, invariant_div_supply: D, underlying_prices: Iterable[D]
) -> D:
    alpha_high_prec = convd(root3Alpha, D3) ** 3
    invariant_div_supply_high_prec = convd(invariant_div_supply, D3)

    pX = convd(underlying_prices[0], D3)
    pY = convd(underlying_prices[1], D3)
    pZ = convd(underlying_prices[2], D3)

    # Relative external (actual) prices
    pXZ = pX / pZ
    pYZ = pY / pZ

    # Relative prices of a pool that is arbitrage-free with the external market
    pXZPool, pYZPool = relativeEquilibriumPricesCPMMV3(alpha_high_prec, pXZ, pYZ)

    gamma = (convd(pXZPool, D3) * convd(pYZPool, D3)) ** (D3(1) / 3)

    # Absolute prices (short notation)
    value_factor = gamma * (
        pX / convd(pXZPool, D3) + pY / convd(pYZPool, D3) + pZ
    ) - convd(root3Alpha, D3) * (pX + pY + pZ)

    return convd(convd(invariant_div_supply_high_prec, D3) * value_factor, D)
