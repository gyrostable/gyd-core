from decimal import Decimal
from typing import (
    Iterable,
    List,
    Literal,
    NamedTuple,
    Union,
    overload,
)

from tests.support.quantized_decimal import DecimalLike, QuantizedDecimal

DEFAULT_DECIMALS = 18


class JoinKind:
    INIT = 0
    EXACT_TOKENS_IN_FOR_BPT_OUT = 1
    TOKEN_IN_FOR_EXACT_BPT_OUT = 2
    ALL_TOKENS_IN_FOR_EXACT_BPT_OUT = 3


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


def isinstance_namedtuple(obj) -> bool:
    return (
        isinstance(obj, tuple) and hasattr(obj, "_asdict") and hasattr(obj, "_fields")
    )


@overload
def scale(x: DecimalLike, decimals: int = ...) -> QuantizedDecimal:
    ...


@overload
def scale(x: Iterable[DecimalLike], decimals: int = ...) -> List[QuantizedDecimal]:
    ...


@overload
def scale(x: NamedTuple, decimals: int = ...) -> NamedTuple:
    ...


def scale(x, decimals=18):
    if isinstance(x, (list, tuple)):
        return [scale(v, decimals) for v in x]
    if isinstance_namedtuple(x):
        return type(x)(*[scale(v, decimals) for v in x])
    return scale_scalar(x, decimals)


def scale_scalar(x: DecimalLike, decimals: int = 18) -> QuantizedDecimal:
    return (to_decimal(x) * 10**decimals).floor()


def unscale_scalar(x: DecimalLike, decimals: int = 18) -> QuantizedDecimal:
    # This is necessary to support very large integers; otherwise, we get an error at
    # to_decimal(x) already.
    if isinstance(x, int):
        return (
            to_decimal(x // 10**decimals)
            + to_decimal(x % 10**decimals) / 10**decimals
        )
    return to_decimal(x) / 10**decimals


def unscale(x, decimals=18):
    if isinstance(x, (list, tuple)):
        return [unscale_scalar(v, decimals) for v in x]
    return unscale_scalar(x, decimals)


def bp(value: DecimalLike) -> int:
    return int(scale(value, 14))
