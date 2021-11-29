from decimal import Decimal
from typing import Union

DEFAULT_DECIMALS = 18


def scale(value: Union[str, int], decimals: int = DEFAULT_DECIMALS):
    multiplier = 10 ** decimals
    return (Decimal(value) * multiplier).quantize(multiplier)


def truncate(value: Decimal, precision: int = 5, decimals: int = DEFAULT_DECIMALS):
    multiplier = 10 ** (decimals - precision)
    return Decimal(value) // multiplier * multiplier
