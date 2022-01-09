from decimal import Decimal
from typing import Literal, Union, overload

from tests.support.quantized_decimal import QuantizedDecimal

DEFAULT_DECIMALS = 18


def scale(
    value: Union[str, int, Decimal, QuantizedDecimal], decimals: int = DEFAULT_DECIMALS
):
    if isinstance(value, QuantizedDecimal):
        value = value.raw
    multiplier = 10 ** decimals
    return (Decimal(value) * multiplier).quantize(multiplier)


def truncate(value: Decimal, precision: int = 5, decimals: int = DEFAULT_DECIMALS):
    multiplier = 10 ** (decimals - precision)
    return Decimal(value) // multiplier * multiplier


@overload
def format_to_bytes(message: Union[str, bytes], length: int) -> bytes:
    ...


@overload
def format_to_bytes(
    message: Union[str, bytes], length: int, output_hex: Literal[False]
) -> bytes:
    ...


@overload
def format_to_bytes(
    message: Union[str, bytes], length: int, output_hex: Literal[True]
) -> str:
    ...


def format_to_bytes(message: Union[str, bytes], length: int, output_hex: bool = False):
    if isinstance(message, str):
        message = message.encode()
    result = int.from_bytes(message, "little").to_bytes(length, "little")
    if output_hex:
        return "0x" + result.hex()
    return result
