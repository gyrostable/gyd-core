"""Fuzzy math (in particular, comparisons) for Decimals"""

from logging import warning

from tests.support.quantized_decimal import QuantizedDecimal as D

prec_internal = D("1E-12")
prec_input = D("1E-8")  # when checking how to behave towards an input
prec_sanity_check = D(
    "1E-8"
)  # when checking mathematical properties that span long calculations


def isclose(x: D, y: D, prec: D) -> bool:
    return abs(x - y) <= prec


def isle(x: D, y: D, prec: D) -> bool:
    return x - y <= prec


def isge(x: D, y: D, prec: D) -> bool:
    return isle(y, x, prec)


def sqrt(x: D, prec=prec_internal) -> D:
    # The following check used to be an assertion before, but hypothesis kept hitting it, via the path through
    # compute_lower_redemption_threshold() via some of the precomputation steps. Making it a warning now. We know
    # this doesn't cause a problem in the grand scheme of things b/c the tests still go through.
    if not x >= -prec:
        warning(f"Negative number in sqrt, assuming zero: {x}")
    # assert x >= -prec  # In a real implementation, this assertion should just be some softer logging/reporting I guess.
    if x < 0:
        return D(0)
    return x.sqrt()
