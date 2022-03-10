from __future__ import annotations

from typing import List, NamedTuple

from tests.support.quantized_decimal import DecimalLike


class MintAsset(NamedTuple):
    inputToken: str
    inputAmount: DecimalLike
    destinationVault: str


class RedeemAsset(NamedTuple):
    outputToken: str
    minOutputAmount: DecimalLike
    valueRatio: DecimalLike
    originVault: str


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


class JoinPoolRequest(NamedTuple):
    assets: List[str]
    max_amounts_in: List[int]
    user_data: bytes
    from_internal_balancer: bool = False


class PersistedVaultMetadata(NamedTuple):
    initial_price: int
    initial_weight: int


class VaultInfo(NamedTuple):
    vault: str
    price: int
    persisted_metadata: PersistedVaultMetadata
    reserve_balance: int
    current_weight: int
    ideal_weight: int

    @classmethod
    def from_tuple(cls, t) -> VaultInfo:
        persisted_metadata = PersistedVaultMetadata(*t[2])
        items = t[:2] + (persisted_metadata,) + t[3:]
        return cls(*items)


class VaultWithAmount(NamedTuple):
    vault_info: VaultInfo
    amount: int

    @classmethod
    def from_tuple(cls, t) -> VaultWithAmount:
        return cls(vault_info=VaultInfo.from_tuple(t[0]), amount=t[1])


class Order(NamedTuple):
    vaults_with_amount: List[VaultWithAmount]
    mint: bool

    @classmethod
    def from_tuple(cls, t) -> Order:
        vaults_with_amount = [VaultWithAmount.from_tuple(v) for v in t[0]]
        return cls(vaults_with_amount=vaults_with_amount, mint=t[1])


class FeedMeta(NamedTuple):
    min_diff_time: int
    max_deviation: int
