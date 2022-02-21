from typing import Dict, Iterable, List, Tuple

from tests.support import constants
from tests.support.quantized_decimal import QuantizedDecimal as D
from tests.support.utils import scale

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


def vault_weight_off_peg_falls(metadata) -> bool:
    for i in metadata[0]:
        if i[6]:
            continue
        if i[4] > i[1]:
            return False
    return True


def update_metadata_with_epsilon_status(metadata):
    metadata_new = list(metadata)
    metadata_new[1] = True

    vaults_metadata = []
    for vault_metadata in metadata_new[0]:
        vault_metadata_new = list(vault_metadata)
        scaled_epsilon = (
            D(vault_metadata[1]) * constants.MAX_ALLOWED_VAULT_DEVIATION / scale("1")
        )
        if abs(vault_metadata[1] - vault_metadata[3]) <= scaled_epsilon:
            within_epsilon = True
        else:
            within_epsilon = False
            metadata_new[1] = False

        vault_metadata_new[8] = within_epsilon
        vaults_metadata.append(tuple(vault_metadata_new))

    metadata_new[0] = vaults_metadata

    return tuple(metadata_new)


def update_vault_with_price_safety(vault_metadata):
    pass


def build_metadata(order: List[Tuple]) -> List[D]:

    metadata = []
    vault_metadata_array = []

    current_amounts = []
    delta_amounts = []
    resulting_amounts = []
    prices = []

    vaults_with_amount = order[0]
    order_type = order[1]

    for vault in vaults_with_amount:
        vault_metadata = []

        current_amounts.append(D(vault[0][3]))
        delta_amounts.append(D(vault[1]))

        if order[1]:
            resulting_amounts.append(D(vault[0][3]) + D(vault[1]))
        else:
            resulting_amounts.append(D(vault[0][3]) - D(vault[1]))

        prices.append(D(vault[0][1]))

        ideal_weights = calculate_ideal_weights(vaults_with_amount)

        current_weights, current_usd_value = calculate_weights_and_total(
            current_amounts, prices
        )
        resulting_weights, resultingTotal = calculate_weights_and_total(
            resulting_amounts, prices
        )

        delta_weights, delta_total = calculate_weights_and_total(delta_amounts, prices)

        vault_metadata.append(vault[0][2][2])
        vault_metadata.append(ideal_weights)

        if current_usd_value == D("0"):
            vault_metadata.append(ideal_weights)
        else:
            vault_metadata.append(current_weights)

        vault_metadata.append(resulting_weights)

        if delta_total == D("0"):
            vault_metadata.append(ideal_weights)
        else:
            vault_metadata.append(delta_weights)

        vault_metadata.append(vault[0][1])
        vault_metadata.append(False)
        vault_metadata.append(False)
        vault_metadata.append(False)

        vault_metadata_array.append(vault_metadata)

    metadata.append(vault_metadata_array)
    metadata.append(False)
    metadata.append(False)
    metadata.append(False)
    metadata.append(order_type)

    return metadata
