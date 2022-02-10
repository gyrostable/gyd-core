from typing import Dict, Iterable, List, Tuple

from tests.support import constants
from tests.support.quantized_decimal import QuantizedDecimal as D

STABLECOIN_IDEAL_PRICE = "1e18"


def calculate_weights_and_total(
    amounts: Iterable[D], prices: Iterable[D]
) -> Tuple[Iterable[D], D]:
    total = 0
    for i in range(len(amounts)):
        amount_in_usd = amounts[i] * prices[i]
        total += amount_in_usd

    if total == 0:
        return [], total

    weights = []
    for i in range(len(amounts)):
        weight = amounts[i] * prices[i] / total
        weights.append(weight)

    return weights, total


def is_stablecoin_close_to_peg(stablecoin_price: D) -> bool:
    off_peg_amount = abs(stablecoin_price - D(STABLECOIN_IDEAL_PRICE))
    if off_peg_amount <= constants.STABLECOIN_MAX_DEVIATION:
        return True
    return False


def calculate_implied_pool_weights(vaults_with_amount: List[dict]):
    implied_ideal_weights = []
    weighted_returns = []

    returns_sum = 0

    for vault in vaults_with_amount:
        weighted_return = (
            vault.vault_info.price
            / vault.vault_info.persisted_metadata_initial_price
            * vault.vault_info.persisted_metadata_initial_weight
        )
        returns_sum += weighted_return
        weighted_returns.append(weighted_return)

    for i in range(len(vaults_with_amount)):
        implied_ideal_weight = weighted_returns[i] / returns_sum
        implied_ideal_weights.append(implied_ideal_weight)

    return implied_ideal_weights
