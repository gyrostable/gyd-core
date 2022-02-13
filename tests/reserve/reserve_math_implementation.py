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


def calculate_ideal_weights(vaults_with_amount: List[Tuple]) -> List[D]:
    implied_ideal_weights = []
    weighted_returns = []

    returns_sum = D("0")

    for vault in vaults_with_amount:
        weighted_return = D(vault[0][1]) / D(vault[0][2][0]) * D(vault[0][2][1])
        returns_sum += D(weighted_return)
        weighted_returns.append(weighted_return)

    for i in range(len(vaults_with_amount)):
        implied_ideal_weight = weighted_returns[i] / returns_sum
        implied_ideal_weights.append(implied_ideal_weight)

    return implied_ideal_weights


def check_any_off_peg_vault_would_move_closer_to_ideal_weight(metadata) -> bool:
    for i in metadata[0]:
        if i[6]:
            continue
        if i[4] > i[1]:
            return False
    return True

def update_metadata_with_epsilon_status(metadata):
    metadata_new = list(metadata)
    metadata_new[1] = True

    for i in metadata_new[0]:
        as_list = list(i)
        scaled_epsilon = D(i[1]) * constants.MAX_ALLOWED_VAULT_DEVIATION / D("10000")
        if abs(i[1] - i[3]) <= scaled_epsilon:
            within_epsilon = True
        else:
            within_epsilon = False

        as_list[8] = within_epsilon

        i = as_list[8]

    return metadata_new

def update_vault_with_price_safety(vault_metadata):
    pass

# def build_metadata(vaults_with_amount: List[Tuple]) -> List[D]:

#     metadata = []

#     current_amounts = []
#     delta_amounts = []
#     resulting_amounts = []
#     prices = []

#     for vault in vaults_with_amount:
#         current_amounts.append(D(vault[0][4]))

#         delta_amounts.append(D(vault[1]))

#         if vault[2]:
#             resulting_amounts.append(D(vault[0][4]) + D(vault[1]))
#         else:
#             resulting_amounts.append(D(vault[0][4]) - D(vault[1]))

#         prices.append(D(vault[0][1]))

#     ideal_weights = calculate_implied_pool_weights(vaults_with_amount)
#     metadata.append(ideal_weights)

#     current_weights, current_usd_value = calculate_weights_and_total(
#         current_amounts, prices
#     )

#     if current_usd_value == D("0"):
#         metadata.append(ideal_weights)
#     else:
#         metadata.append(current_weights)

#     resulting_weights, resultingTotal = calculate_weights_and_total(
#         resulting_amounts, prices
#     )

#     metadata.append(resulting_weights)

#     delta_weights, delta_total = calculate_weights_and_total(delta_amounts, prices)

#     if delta_total == D("0"):
#         metadata.append(ideal_weights)
#     else:
#         metadata.append(delta_weights)

#     metadata.append(prices)

#     metadata.append(delta_total)

#     return metadata
