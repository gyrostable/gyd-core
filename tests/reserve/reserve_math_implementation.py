from typing import Dict, Iterable, List, Tuple

from tests.support.quantized_decimal import QuantizedDecimal as D


def calculate_weights_and_total(amounts: Iterable[D], prices: Iterable[D]) -> Tuple[Iterable[D], D]:
    total = 0
    for i in range(len(amounts)):
        amount_in_usd = amounts[i] * prices[i]
        total+= amount_in_usd

    if total == 0:
        return [], total

    weights = []
    for i in range(len(amounts)):
        weight = amounts[i] * prices[i] / total
        weights.append(weight)

    return weights, total

def calculate_implied_pool_weights(vaults_with_amount: List[dict]):
    implied_ideal_weights = []
    weighted_returns = []

    returns_sum = 0

    for vault in vaults_with_amount:
        weighted_return = vault.vault_info.price / vault.vault_info.persisted_metadata_initial_price *vault.vault_info.persisted_metadata_initial_weight 
        returns_sum += weighted_return
        weighted_returns.append(weighted_return)

    for i in range(len(vaults_with_amount)):
        implied_ideal_weight = weighted_returns[i] / returns_sum
        implied_ideal_weights.append(implied_ideal_weight)


    return implied_ideal_weights
