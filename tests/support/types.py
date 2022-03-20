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
    short_flow_memory: int
    short_flow_threshold: int


class PricedToken(NamedTuple):
    tokenAddress: str
    price: int


class VaultInfo(NamedTuple):
    vault: str
    decimals: int
    price: int
    persisted_metadata: PersistedVaultMetadata
    reserve_balance: int
    current_weight: int
    ideal_weight: int
    priced_tokens: List[PricedToken]

    @classmethod
    def from_tuple(cls, t) -> VaultInfo:
        persisted_metadata = PersistedVaultMetadata(*t[3])
        priced_tokens = [PricedToken(*v) for v in t[-1]]
        items = t[:3] + (persisted_metadata,) + t[4:-1] + (priced_tokens,)
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


class VaultType:
    GENERIC = 0
    BALANCER_CPMM = 1
    BALANCER_CPMMV2 = 2
    BALANCER_CPMMV3 = 3
    BALANCER_CEMM = 4


class VaultToDeploy(NamedTuple):
    pool: str
    address: str
    initial_weight: int
    short_flow_memory: int
    short_flow_threshold: int
    mint_fee: int
    redeem_fee: int


class PammParams(NamedTuple):
    alpha_bar: int  # ᾱ ∊ [0,1]
    xu_bar: int  # x̄_U ∊ [0,1]
    theta_bar: int  # θ̄ ∊ [0,1]
    outflow_memory: int  #  [0,1]
