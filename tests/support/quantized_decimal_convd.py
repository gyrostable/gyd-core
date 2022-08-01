import decimal
from tests.support.quantized_decimal import QuantizedDecimal as D
from tests.support.quantized_decimal_38 import QuantizedDecimal as D2
from tests.support.quantized_decimal_100 import QuantizedDecimal as D3


def convd(x, totype, dofloat=True, dostr=True):
    """totype: one of D, D2, D3, i.e., some QuantizedDecimal implementation.

    `dofloat`: Also convert floats.

    `dostr`: Also convert str.

    Example: convd(x, D3)"""

    def go(y):
        if isinstance(y, decimal.Decimal):
            return totype(y)
        elif isinstance(y, (D, D2, D3)):
            return totype(y.raw)
        elif dofloat and isinstance(y, float):
            return totype(y)
        elif dostr and isinstance(y, str):
            return totype(y)
        else:
            return y

    return apply_deep(x, go)


def apply_deep(x, f):
    # Order matters b/c named tuples are tuples.
    if isinstance_namedtuple(x):
        return type(x)(*[apply_deep(y, f) for y in x])
    if isinstance(x, (list, tuple)):
        return type(x)([apply_deep(y, f) for y in x])
    return f(x)


def isinstance_namedtuple(obj) -> bool:
    return (
        isinstance(obj, tuple) and hasattr(obj, "_asdict") and hasattr(obj, "_fields")
    )
