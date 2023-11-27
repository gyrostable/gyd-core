from dataclasses import dataclass
from enum import Enum
from functools import cached_property
from typing import Optional, Tuple, Union

from tests.support.dfuzzy import isge, isle, prec_input, sqrt
from tests.support.quantized_decimal import QuantizedDecimal as D


class Region(Enum):
    CASE_i = 0
    CASE_I_ii = 1
    CASE_I_iii = 2
    CASE_II_H = 3
    CASE_II_L = 4
    CASE_III_H = 5
    CASE_III_L = 6
    CASE_low = 10  # Any case where r <= theta_bar and where the region therefore cannot be reconstructed.
    CASE_high = 20  # Any case where r >= 1 and where the region therefore cannot be reconstructed. (this is iff ra >= 1)

    @staticmethod
    def from_pieces(r1: Union[str, None], r2: Union[str, None], r3: Union[str, None]):
        if r1 is not None:
            r1 = r1.upper()
        if r2 is not None:
            r2 = r2.upper()
        if r3 is not None:
            r3 = r3.lower()
        r = (r1, r2, r3)
        for ps, rc in _pieces2region_rules:
            if all(b is None or a == b for a, b in zip(r, ps)):
                return rc
        raise ValueError("Region pieces don't fit any region")

    def to_pieces(self):
        for ps, rc in _pieces2region_rules:
            if rc == self:
                return ps
        raise AssertionError("Missing region in rules")


# Order matters!
_pieces2region_rules = [
    ((None, None, "i"), Region.CASE_i),
    (("I", None, "ii"), Region.CASE_I_ii),
    (("I", None, "iii"), Region.CASE_I_iii),
    ((None, None, "iii"), Region.CASE_low),
    (("II", "H", None), Region.CASE_II_H),
    (("II", "L", None), Region.CASE_II_L),
    (("III", "H", None), Region.CASE_III_H),
    (("III", "L", None), Region.CASE_III_L),
]


@dataclass
class Params:
    decay_slope_lower_bound: D = D("0.6")  # ᾱ
    stable_redeem_threshold_upper_bound: D = D("0.3")  # x̄_U
    target_reserve_ratio_floor: D = D("0.6")  # θ̄

    @cached_property
    def target_utilization_ceiling(self):
        return 1 - self.target_reserve_ratio_floor

    @cached_property
    def ba_threshold_region_I(self):  # b_a^{I/II}
        return compute_relative_reserve_for_xu(
            self.stable_redeem_threshold_upper_bound, D(1), self
        )

    @cached_property
    def ba_threshold_region_II(self):  # b_a^{II/III}
        return compute_relative_reserve_for_xu(D(0), D(1), self)

    @cached_property
    def xl_threshold_at_threshold_I(self):  # x_L^{I/II}
        ba = self.ba_threshold_region_I
        xu = self.stable_redeem_threshold_upper_bound
        alpha = self.decay_slope_lower_bound
        return compute_lower_redemption_threshold(ba, D(1), alpha, xu)

    @cached_property
    def xl_threshold_at_threshold_II(self):  # x_L^{II/III}
        ba = self.ba_threshold_region_II
        xu = D(0)
        alpha = self.decay_slope_lower_bound
        return compute_lower_redemption_threshold(ba, D(1), alpha, xu)

    @cached_property
    def ba_threshold_II_hl(self):  # ba^{h/l}
        denom = 2 * self.decay_slope_lower_bound
        num = self.target_utilization_ceiling**2
        return D(1) - num / denom  # type: ignore

    @cached_property
    def xu_threshold_II_hl(self):  # x_U^{h/l}
        ba = self.ba_threshold_II_hl
        alpha = self.decay_slope_lower_bound
        return compute_upper_redemption_threshold(
            ba,
            D(1),
            alpha,
            self.stable_redeem_threshold_upper_bound,
            self.target_utilization_ceiling,
        )

    @cached_property
    def xl_threshold_II_hl(self):  # x_L^{h/l}
        # TODO check if we can just replace this by D(1)
        return compute_lower_redemption_threshold(
            self.ba_threshold_II_hl,
            D(1),
            self.decay_slope_lower_bound,
            self.xu_threshold_II_hl,
        )

    @cached_property
    def ba_threshold_III_hl(self):  # ba^{H/L}
        return (D(1) + self.target_reserve_ratio_floor) / 2

    @cached_property
    def slope_threshold_III_HL(self):  # α^{H/L}
        ba = self.ba_threshold_III_hl
        return compute_slope(
            ba, D(1), self.target_reserve_ratio_floor, self.decay_slope_lower_bound
        )

    @cached_property
    def xl_threshold_III_HL(self):  # x_L^{H/L}
        # TODO check if we can just replace this by D(1)
        return compute_lower_redemption_threshold(
            self.ba_threshold_III_hl, D(1), self.slope_threshold_III_HL, D(0)
        )


def compute_relative_reserve_for_xu(
    xu: D, ya: D, params: Params, alpha: Optional[D] = None
):
    """Lemma 4. ba s.t. x_U^ = z given the above values."""
    assert ya >= xu, "ya must be greater than xu"
    if alpha is None:
        alpha = params.decay_slope_lower_bound / ya
    yz = ya - xu
    target_usage = 1 - params.target_reserve_ratio_floor
    if 1 - alpha * yz >= params.target_reserve_ratio_floor:
        return ya - alpha / 2 * yz**2
    return ya - target_usage * yz + target_usage**2 / (2 * alpha)


def compute_lower_redemption_threshold(ba: D, ya: D, alpha: D, xu: D):
    if ba / ya >= 1:
        return ya
    return ya - sqrt((ya - xu) ** 2 - 2 / alpha * (ya - ba))


def compute_upper_redemption_threshold_unconstrained(
    ba: D, ya: D, alpha: D, theta: D
) -> D:
    delta = ya - ba
    if alpha * delta <= theta**2 / 2:
        return ya - sqrt(2 * delta / alpha)
    else:
        return ya - delta / theta - theta / (2 * alpha)


def compute_upper_redemption_threshold(
    ba: D, ya: D, alpha: D, xu_bar: D, theta: D
) -> D:
    xu_max = xu_bar * ya
    xu_hat = compute_upper_redemption_threshold_unconstrained(ba, ya, alpha, theta)
    return max(D(0), min(xu_max, xu_hat))


def compute_slope_unconstrained(ba: D, ya: D, theta_bar: D) -> D:
    ra = ba / ya
    theta = 1 - theta_bar
    assert ra > theta_bar  # O/w the slope is infinite or makes no sense.

    if ra >= (1 + theta_bar) / 2:
        return 2 * (1 - ra) / ya
    else:
        # TODO Highway to the rounding error danger zone if ba/ya ≈ theta_floor
        return theta**2 / (2 * (ba - theta_bar * ya))


def compute_slope(ba: D, ya: D, theta_bar: D, alpha_bar: D) -> D:
    alpha_min = alpha_bar / ya
    alpha = compute_slope_unconstrained(ba, ya, theta_bar)
    return max(alpha_min, alpha)


def compute_fixed_reserve(x: D, ba: D, ya: D, alpha: D, xu: D, xl: D) -> D:
    if x <= xu:
        return ba - x
    if x <= xl:
        return ba - x + alpha / 2 * (x - xu) ** 2
    # x >= xl:
    rl = 1 - alpha * (xl - xu)
    return rl * (ya - x)


def compute_reserve(x: D, ba: D, ya: D, params: Params) -> D:
    if ba / ya > 1:
        return ba - x
    if ba / ya <= params.target_reserve_ratio_floor:
        return ba - ba / ya * x

    alpha = compute_slope(
        ba,
        ya,
        params.target_reserve_ratio_floor,
        params.decay_slope_lower_bound,
    )
    xu = compute_upper_redemption_threshold(
        ba,
        ya,
        alpha,
        params.stable_redeem_threshold_upper_bound,
        params.target_utilization_ceiling,
    )
    xl = compute_lower_redemption_threshold(ba, ya, alpha, xu)
    return compute_fixed_reserve(x, ba, ya, alpha, xu, xl)


def compute_region_ext(
    x: D, ba: D, ya: D, params: Params, prec=D(0)
) -> Tuple[Optional[str], Optional[str], Optional[str]]:
    """Compute region when we know everything. Only for testing.

    This computes the 'extended' region, which also always stores i-iii and is slightly more than we need to know for reconstruction.

    prec = precision for fuzzy comparison. This can be 0; otherwise, it biases the comparison towards 'higher' regions.
    """

    xu_max = params.stable_redeem_threshold_upper_bound * ya
    alpha_min = params.decay_slope_lower_bound / ya

    if ba >= ya:
        return None, None, "i"

    if isle(ba, ya * params.target_reserve_ratio_floor, prec):
        return None, None, "iii"

    alpha_hat = compute_slope_unconstrained(
        ba, ya, params.target_reserve_ratio_floor
    )  # Unconstrained to robustly define regions
    alpha = max(alpha_min, alpha_hat)
    xu_hat = compute_upper_redemption_threshold_unconstrained(
        ba, ya, alpha, params.target_utilization_ceiling
    )
    xu = min(xu_max, xu_hat)
    theta_floor = params.target_reserve_ratio_floor
    xl = compute_lower_redemption_threshold(ba, ya, alpha, xu)
    deltaa = ya - ba
    ra = ba / ya

    # DEBUG
    # print(dict(alphahat=alpha_hat, alphamin=alpha_min, xuhat=xu_hat, xumax=xu_max))

    if isle(alpha_hat, alpha_min, prec) and isge(xu_hat, xu_max, prec):
        d1 = "I"
        d2 = None
    elif isle(alpha_hat, alpha_min, prec):
        d1 = "II"
        d2 = (
            "h"
            if isle(alpha * deltaa, D(1) / 2 * (1 - theta_floor) ** 2, prec)
            else "l"
        )
    else:
        d1 = "III"
        d2 = "H" if isge(ra, (1 + theta_floor) / 2, prec) else "L"

    if isle(x, xu, prec):
        d3 = "i"
    elif isle(x, xl, prec):
        d3 = "ii"
    else:
        d3 = "iii"

    return d1, d2, d3


def compute_region(x: D, ba: D, ya: D, params: Params, prec=D(0)) -> Region:
    """For testing. Compute the Region, which should also be detected by Pamm._compute_current_region().

    We return None iff we are below the floor (which doesn't have a region b/c it's caught early)
    """
    print("PARAMS", params)
    r = compute_region_ext(x, ba, ya, params, prec)
    return Region.from_pieces(*r)


def compute_price(x: D, ba: D, ya: D, params: Params) -> D:
    """Spot price."""
    if ba >= ya:
        return D(1)
    if ba <= ya * params.target_reserve_ratio_floor:
        return ba / ya

    alpha = compute_slope(
        ba, ya, params.target_reserve_ratio_floor, params.decay_slope_lower_bound
    )
    xu = compute_upper_redemption_threshold(
        ba,
        ya,
        alpha,
        params.stable_redeem_threshold_upper_bound,
        params.target_utilization_ceiling,
    )
    xl = compute_lower_redemption_threshold(ba, ya, alpha, xu)
    if x <= xu:
        return D(1)
    elif x <= xl:
        return D(1) - alpha * (x - xu)
    else:
        return D(1) - alpha * (xl - xu)


class Pamm:
    def __init__(self, params: Params):
        self.params = params
        self.redemption_level = D(0)
        self.total_gyro_supply = D(0)
        self.reserve_value = D(0)

    def _is_in_first_region(self, scaled_reserve: D, scaled_redemption: D) -> bool:
        return scaled_reserve >= compute_fixed_reserve(
            scaled_redemption,
            self.params.ba_threshold_region_I,
            D(1),
            self.params.decay_slope_lower_bound,
            self.params.stable_redeem_threshold_upper_bound,
            self.params.xl_threshold_at_threshold_I,
        )

    def _is_in_second_region(self, scaled_reserve: D, scaled_redemption: D) -> bool:
        return scaled_reserve >= compute_fixed_reserve(
            scaled_redemption,
            self.params.ba_threshold_region_II,
            D(1),
            self.params.decay_slope_lower_bound,
            D(0),
            self.params.xl_threshold_at_threshold_II,
        )

    def _is_in_second_subcase(self, scaled_reserve: D, scaled_redemption: D) -> bool:
        """Assuming we're in case II, whether we're in case h (or otherwise l)"""
        # Check if case l or h, respectively, even exist. This is required!
        if self.params.ba_threshold_II_hl >= self.params.ba_threshold_region_I:
            return False
        elif self.params.ba_threshold_II_hl <= self.params.ba_threshold_region_II:
            return True
        return scaled_reserve >= compute_fixed_reserve(
            scaled_redemption,
            self.params.ba_threshold_II_hl,
            D(1),
            self.params.decay_slope_lower_bound,
            self.params.xu_threshold_II_hl,
            self.params.xl_threshold_II_hl,
        )

    def _is_in_high_subcase(self, scaled_reserve: D, scaled_redemption: D) -> bool:
        """Assuming we're in case III, whether we're in case H (or otherwise L)"""
        # Check if case L or H, respectively, even exist. This is required!
        if self.params.ba_threshold_III_hl >= self.params.ba_threshold_region_II:
            return False
        return scaled_reserve >= compute_fixed_reserve(
            scaled_redemption,
            self.params.ba_threshold_III_hl,
            D(1),
            self.params.slope_threshold_III_HL,
            D(0),
            self.params.xl_threshold_III_HL,
        )

    def compute_redeem_amount(self, amount: D) -> D:
        reserve_ratio = self.reserve_value / self.total_gyro_supply

        if reserve_ratio >= 1:
            # TODO should this be fuzzy comparison to swallow almost-1 values? (these may just be fine actually)
            return amount

        if isle(reserve_ratio, self.params.target_reserve_ratio_floor, prec_input):
            return reserve_ratio * amount

        ya = self.total_gyro_supply + self.redemption_level
        ba_normalized = self._compute_normalized_anchor_reserve_value()
        ba = ba_normalized * ya

        # todo maybe use the computed region information to avoid some of the calculations in `compute_reserve()`.
        # We can use info regarding case I-III and H/L because they don't depend on x.
        # (We can't use info on i-iii because they depend on x)
        # Not clear to me how much benefit this brings
        next_reserve_value = compute_reserve(
            self.redemption_level + amount, ba, ya, self.params
        )
        return self.reserve_value - next_reserve_value

    def _compute_normalized_anchor_reserve_value(self) -> D:
        """Assume that the reserve ratio b/y is in the open inverval (theta_floor, 1) (incl. a margin for errors).
        These edge cases are handled by `_compute_redeem_amount()`"""

        ya = self.total_gyro_supply + self.redemption_level

        region = self._compute_normalized_current_region()

        # Normalized values to ya=1. All the values below are scaled to ya=1 as well. We only work with normalized
        # values in the following and also return the normalized reconstructed ba.
        scaled_redemption = self.redemption_level / ya  # type: ignore
        scaled_reserve = self.reserve_value / ya  # type: ignore
        scaled_supply = self.total_gyro_supply / ya  # type: ignore

        reserve_ratio = self.reserve_value / self.total_gyro_supply
        used_ratio = 1 - reserve_ratio
        theta_floor = self.params.target_reserve_ratio_floor
        theta = self.params.target_utilization_ceiling

        one = D(1)  # = normalized ya

        xu_max = self.params.stable_redeem_threshold_upper_bound
        alpha_min = self.params.decay_slope_lower_bound

        if region == Region.CASE_i:
            return scaled_reserve + scaled_redemption

        if region == Region.CASE_I_ii:
            return (
                scaled_reserve
                + scaled_redemption
                - alpha_min * (scaled_redemption - xu_max) ** 2 / 2
            )

        if region == Region.CASE_I_iii:
            lh = one - (one - xu_max) * used_ratio  # type: ignore
            return lh + used_ratio**2 / (2 * alpha_min)

        if region == Region.CASE_II_H:
            delta = alpha_min * (used_ratio / alpha_min + scaled_supply / 2) ** 2 / 2
            return one - delta

        if region == Region.CASE_II_L:
            p = theta * (theta / (2 * alpha_min) + scaled_supply)
            d = (
                theta**2
                * 2
                / alpha_min
                * (scaled_reserve - theta_floor * scaled_supply)
            )
            return one - p + sqrt(d)

        if region == Region.CASE_III_H:
            delta = (scaled_supply - scaled_reserve) / (
                1
                - (scaled_redemption**2)  # exploit that the scaled value of ya is 1.
            )
            return one - delta

        if region == Region.CASE_III_L:
            p = (scaled_supply - scaled_reserve + theta * one) / 2  # type: ignore
            q = (
                scaled_supply - scaled_reserve
            ) * theta * one + theta**2 * scaled_redemption**2 / 4
            delta = p - sqrt(p**2 - q)
            return one - delta

        raise ValueError("unknown region")

    def compute_anchor_reserve_value(self):
        """For testing only, o/w not needed. None if we wouldn't and don't need to compute this."""
        if self.reserve_value >= self.total_gyro_supply:
            return self.reserve_value + self.redemption_level
        if isle(
            self.reserve_value / self.total_gyro_supply,
            self.params.target_reserve_ratio_floor,
            prec_input,
        ):
            return None
        return self._compute_normalized_anchor_reserve_value() * (
            self.total_gyro_supply + self.redemption_level
        )

    def _compute_normalized_current_region(self) -> Region:
        """We assume that b/y is in the open interval (theta_floor, 1). O/w this is caught higher up in the call
        graph.

        Note that the region wrt. normalized values is the same as wrt. non-normalized values. We still need to do
        the normalization correctly to use our precomputed values."""
        reserve_ratio = self.reserve_value / self.total_gyro_supply

        ya = self.total_gyro_supply + self.redemption_level
        # Normalize. All values below are normalized, too.
        scaled_redemption = self.redemption_level / ya  # type: ignore
        scaled_reserve = self.reserve_value / ya  # type: ignore
        scaled_supply = self.total_gyro_supply / ya  # type: ignore

        xu_max = self.params.stable_redeem_threshold_upper_bound
        alpha_min = self.params.decay_slope_lower_bound
        theta_floor = self.params.target_reserve_ratio_floor
        theta = self.params.target_utilization_ceiling

        # todo maybe should some of these be replaced by fuzzy comparison to improve numerical stability?
        if self._is_in_first_region(scaled_reserve, scaled_redemption):
            # case I
            if scaled_redemption <= xu_max:
                return Region.CASE_i
            if reserve_ratio <= 1 - alpha_min * (scaled_redemption - xu_max):
                return Region.CASE_I_ii
            return Region.CASE_I_iii

        if self._is_in_second_region(scaled_reserve, scaled_redemption):
            # case II
            if self._is_in_second_subcase(scaled_reserve, scaled_redemption):
                # case h
                if scaled_supply - scaled_reserve <= alpha_min / 2 * scaled_supply**2:
                    return Region.CASE_i
                return Region.CASE_II_H

            if scaled_reserve - theta_floor * scaled_supply >= theta**2 / (
                2 * alpha_min
            ):
                return Region.CASE_i
            return Region.CASE_II_L

        if self._is_in_high_subcase(scaled_reserve, scaled_redemption):
            return Region.CASE_III_H

        return Region.CASE_III_L

    def _compute_current_region_ext(self):
        """Extended reconstructed region. For testing only."""
        reserve_ratio = self.reserve_value / self.total_gyro_supply
        if reserve_ratio >= 1:
            # Special marker for this case.
            return "A", None, "i"
        if reserve_ratio <= self.params.target_reserve_ratio_floor:
            return None, None, "iii"
        return Region.to_pieces(self._compute_normalized_current_region())

    def redeem(self, amount: D) -> D:
        if amount == 0:
            return D(0)
        redeem_amount = self.compute_redeem_amount(amount)
        self.redemption_level += amount
        self.total_gyro_supply -= amount
        self.reserve_value -= redeem_amount
        return redeem_amount

    def update_state(self, redemption_level: D, reserve_value: D, total_gyro_supply: D):
        self.redemption_level = redemption_level
        self.reserve_value = reserve_value
        self.total_gyro_supply = total_gyro_supply
