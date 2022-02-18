from collections import namedtuple

from typing import NamedTuple

from tests.support.quantized_decimal import DecimalLike


class MintAsset(NamedTuple):
    inputToken: str
    inputAmount: DecimalLike
    destinationVault: str


class CEMMMathParams(NamedTuple):
    alpha: DecimalLike
    beta: DecimalLike
    c: DecimalLike
    s: DecimalLike
    lam: DecimalLike


class Vector2(NamedTuple):
    x: DecimalLike
    y: DecimalLike


class CEMMMathDerivedParams(NamedTuple):
    tauAlpha: Vector2
    tauBeta: Vector2
