from decimal import Decimal
from typing import (Iterable, List, Literal, NamedTuple, Optional, Union,
                    overload)

from tests.support.quantized_decimal import DecimalLike, QuantizedDecimal

DEFAULT_DECIMALS = 18


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

def scalar_to_decimal(x: DecimalLike):
    assert isinstance(x, (Decimal, int, str, QuantizedDecimal))
    if isinstance(x, QuantizedDecimal):
        return x
    return QuantizedDecimal(x)


@overload
def to_decimal(x: DecimalLike) -> QuantizedDecimal:
    ...


@overload
def to_decimal(x: Iterable[DecimalLike]) -> List[QuantizedDecimal]:
    ...


def to_decimal(x):
    if isinstance(x, (list, tuple)):
        return [scalar_to_decimal(v) for v in x]
    return scalar_to_decimal(x)

@overload
def scale(x: DecimalLike, decimals=...) -> QuantizedDecimal:
    ...


@overload
def scale(x: Iterable[DecimalLike], decimals=...) -> List[QuantizedDecimal]:
    ...


@overload
def scale(x: NamedTuple, decimals: Optional[int]) -> NamedTuple:
    ...


def isinstance_namedtuple(obj) -> bool:
    return (
        isinstance(obj, tuple) and hasattr(obj, "_asdict") and hasattr(obj, "_fields")
    )


def scale(x, decimals=18):
    if isinstance(x, (list, tuple)):
        return [scale(v, decimals) for v in x]
    if isinstance_namedtuple(x):
        return type(x)(*[scale(v, decimals) for v in x])
    return scale_scalar(x, decimals)

def scale_scalar(x: DecimalLike, decimals: int = 18) -> QuantizedDecimal:
    return (to_decimal(x) * 10**decimals).floor()
