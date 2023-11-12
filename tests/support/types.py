from __future__ import annotations

from typing import List, NamedTuple
from tests.support import constants

from tests.support.quantized_decimal import DecimalLike
from tests.support.utils import scale


class MintAsset(NamedTuple):
    inputToken: str
    inputAmount: DecimalLike
    destinationVault: str


class RedeemAsset(NamedTuple):
    outputToken: str
    minOutputAmount: DecimalLike
    valueRatio: DecimalLike
    originVault: str


class ECLPMathParams(NamedTuple):
    alpha: DecimalLike
    beta: DecimalLike
    c: DecimalLike
    s: DecimalLike
    lam: DecimalLike


class Vector2(NamedTuple):
    x: DecimalLike
    y: DecimalLike


class ECLPMathDerivedParams(NamedTuple):
    tauAlpha: Vector2
    tauBeta: Vector2


class JoinPoolRequest(NamedTuple):
    assets: List[str]
    max_amounts_in: List[int]
    user_data: bytes
    from_internal_balancer: bool = False


class PersistedVaultMetadata(NamedTuple):
    price_at_calibration: int
    weight_at_calibration: int
    short_flow_memory: int
    short_flow_threshold: int
    weight_transition_duration: int = 86_400 * 7
    weight_at_previous_calibration: int = 0
    time_of_calibration: int = 0


class Range(NamedTuple):
    floor: int = int(scale("1") - constants.STABLECOIN_MAX_DEVIATION)
    ceiling: int = int(scale("1") + constants.STABLECOIN_MAX_DEVIATION)


class PricedToken(NamedTuple):
    tokenAddress: str
    is_stable: bool
    price: int
    price_range: Range = Range()


class VaultInfo(NamedTuple):
    vault: str
    decimals: int
    underlying: str
    price: int
    persisted_metadata: PersistedVaultMetadata
    reserve_balance: int
    current_weight: int
    target_weight: int
    priced_tokens: List[PricedToken]

    @classmethod
    def from_tuple(cls, t) -> VaultInfo:
        persisted_metadata = PersistedVaultMetadata(*t[4])
        priced_tokens = [PricedToken(*v) for v in t[-1]]
        items = t[:4] + (persisted_metadata,) + t[5:-1] + (priced_tokens,)
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
    BALANCER_2CLP = 2
    BALANCER_3CLP = 3
    BALANCER_ECLP = 4


class FlowDirection:
    IN = 0
    OUT = 1
    BOTH = 2


class VaultToDeploy(NamedTuple):
    pool_id: str
    vault_type: int
    name: str
    symbol: str
    initial_weight: int
    short_flow_memory: int
    short_flow_threshold: int
    mint_fee: int
    redeem_fee: int


class GenericVaultToDeploy(NamedTuple):
    underlying: str
    name: str
    symbol: str
    initial_weight: int
    short_flow_memory: int
    short_flow_threshold: int
    mint_fee: int
    redeem_fee: int


class DisconnectedGenericVaultToDeploy(NamedTuple):
    """For GenericVaults that are not going into the reserve (aka wrappers)."""
    underlying: str
    name: str
    symbol: str


class DeployedVault(NamedTuple):
    address: str
    vault_to_deploy: VaultToDeploy


class PammParams(NamedTuple):
    alpha_bar: int  # ᾱ ∊ [0,1]
    xu_bar: int  # x̄_U ∊ [0,1]
    theta_bar: int  # θ̄ ∊ [0,1]
    outflow_memory: int  #  [0,1]


class ExternalAction(NamedTuple):
    target: str
    data: str


class VaultConfiguration(NamedTuple):
    vault_address: str
    metadata: PersistedVaultMetadata

    def as_dict(self):
        return {
            "vault_address": self.vault_address,
            "metadata": self.metadata._asdict(),
        }


class RateProviderInfo(NamedTuple):
    underlying: str
    provider: str
