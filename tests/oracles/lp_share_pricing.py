from operator import add, sub
from typing import Iterable

from tests.support.quantized_decimal import QuantizedDecimal as D


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


def price_bpt_cpmm(
    weights: Iterable[D], invariant_div_supply: D, underlying_prices: Iterable[D]
) -> D:
    prod = invariant_div_supply
    for i in range(len(weights)):
        prod = prod * (underlying_prices[i] / weights[i]) ** weights[i]
    return prod


def price_bpt_CPMM_equal_weights(
    weight: D, invariant_div_supply: D, underlying_prices: Iterable[D]
) -> D:
    prod = D("1")
    for i in range(len(underlying_prices)):
        prod = prod * underlying_prices[i] / weight
    prod = prod ** weight
    return prod * invariant_div_supply


def price_bpt_CPMMv2(
    sqrt_alpha: D, sqrt_beta: D, invariant_div_supply: D, underlying_prices: Iterable[D]
) -> D:
    px, py = (underlying_prices[0], underlying_prices[1])
    term = 2 * (px * py) ** D("0.5") - px / sqrt_beta - py * sqrt_alpha
    return term * invariant_div_supply


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
    px, py = (underlying_prices[0], underlying_prices[1])
    sub_vec = mul_Ainv(params, tau(params, px / py))
    vecx = mul_Ainv(params, derived_params.tau_beta)[0] - sub_vec[0]
    vecy = mul_Ainv(params, derived_params.tau_alpha)[0] - sub_vec[1]
    return scalar_prod((px, py), (vecx, vecy)) * invariant_div_supply


def scalar_prod(t1: tuple[D, D], t2: tuple[D, D]) -> D:
    return t1[0] * t2[0] + t1[1] * t2[1]


def mul_Ainv(params: CEMM_params, t: tuple[D, D]) -> tuple[D, D]:
    vecx = params.c * params.lam * t[0] + params.s * t[1]
    vecy = -params.s * params.lam * t[0] + params.c * t[1]
    return (vecx, vecy)


def mul_A(params: CEMM_params, tp: tuple[D, D]) -> tuple[D, D]:
    vecx = params.c / params.lam * tp[0] - params.s / params.lam * tp[1]
    vecy = params.s * tp[0] + params.c * tp[1]
    return (vecx, vecy)


def zeta(params: CEMM_params, px: D) -> D:
    nd = mul_A(params, (-1, px))
    return -nd[1] / nd[0]


def tau(params: CEMM_params, px: D) -> tuple[D, D]:
    return eta(zeta(params, px))


def eta(pxc: D) -> tuple[D, D]:
    z = (1 + pxc ** 2) ** D("0.5")
    vecx = pxc / z
    vecy = 1 / z
    return (vecx, vecy)
