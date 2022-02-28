from curses import meta
from importlib.metadata import metadata
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


def build_metadata(order: List[Tuple], tokens) -> List[D]:

    metadata = []
    vault_metadata_array = []

    current_amounts = []
    delta_amounts = []
    resulting_amounts = []
    prices = []

    vaults_with_amount = order[0]

    ideal_weights = calculate_ideal_weights(vaults_with_amount)

    for vault in vaults_with_amount:
        vault_info = vault[0]

        current_amounts.append(D(vault_info[3]))
        delta_amounts.append(D(vault[1]))

        if order[1]:
            resulting_amounts.append(D(vault_info[3]) + D(vault[1]))
        else:
            resulting_amounts.append(D(vault_info[3]) - D(vault[1]))

        prices.append(D(vault_info[1]))

    current_weights, current_usd_value = calculate_weights_and_total(
        current_amounts, prices
    )
    resulting_weights, resultingTotal = calculate_weights_and_total(
        resulting_amounts, prices
    )

    if len(resulting_weights) == 0:
        resulting_weights = []
        for i in range(len(resulting_amounts)):
            resulting_weights.append(D("0"))

    delta_weights, delta_total = calculate_weights_and_total(delta_amounts, prices)

    if current_usd_value == D("0"):
        current_weights = ideal_weights

    if delta_total == D("0"):
        delta_weights = ideal_weights

    for i in range(len(vaults_with_amount)):
        vault_info = vaults_with_amount[i][0]

        vault_metadata = []

        vault_metadata.append(tokens[i])
        vault_metadata.append(ideal_weights[i])
        vault_metadata.append(current_weights[i])
        vault_metadata.append(resulting_weights[i])
        vault_metadata.append(delta_weights[i])
        vault_metadata.append(vault_info[1])
        vault_metadata.append(False)
        vault_metadata.append(False)
        vault_metadata.append(False)

        vault_metadata_array.append(vault_metadata)

    metadata.append(vault_metadata_array)
    metadata.append(False)
    metadata.append(False)
    metadata.append(False)
    metadata.append(order[1])

    return metadata


def is_mint_safe(order: List[Tuple], tokens, mock_price_oracle, asset_registry) -> str:
    metadata = build_metadata(order, tokens)
    metadata = update_metadata_with_price_safety(
        metadata, mock_price_oracle, asset_registry
    )
    metadata = update_metadata_with_epsilon_status(metadata)

    if not metadata[3]:
        return "55"

    if metadata[1]:
        if metadata[2]:
            return ""
        elif vault_weight_off_peg_falls(metadata):
            return ""
    elif safe_to_execute_outside_epsilon(metadata) & vault_weight_off_peg_falls(
        metadata
    ):
        return ""

    return "52"


def is_redeem_feasible(order: List[Tuple]):
    for vault in order[0]:
        if vault[0][3] < vault[1]:
            return False
    return True


def is_redeem_safe(
    order: List[Tuple], tokens, mock_price_oracle, asset_registry
) -> str:
    if not is_redeem_feasible(order):
        return "56"

    metadata = build_metadata(order, tokens)
    metadata = update_metadata_with_price_safety(
        metadata, mock_price_oracle, asset_registry
    )
    metadata = update_metadata_with_epsilon_status(metadata)

    if not metadata[3]:
        return "55"

    if metadata[1]:
        print("All vaults in epsilon")
        return ""
    elif safe_to_execute_outside_epsilon(metadata):
        print("Safe outside epsilon")
        return ""

    return "53"


def update_vault_with_price_safety(
    vault_metadata: List, mock_price_oracle, asset_registry
):
    tokens = vault_metadata[0]

    vault_metadata[6] = True
    vault_metadata[7] = False

    for token in tokens:
        token_price = mock_price_oracle.getPriceUSD(token)
        if asset_registry.isAssetStable(token):
            vault_metadata[7] = True
            if (abs(token_price - D("1e18"))) > constants.STABLECOIN_MAX_DEVIATION:
                vault_metadata[6] = False
        elif token_price >= constants.MIN_TOKEN_PRICE:
            vault_metadata[7] = True

    return vault_metadata


def update_metadata_with_price_safety(metadata, mock_price_oracle, asset_registry):
    metadata[2] = True
    metadata[3] = True
    for vault_metadata in metadata[0]:
        new_vault_metadata = update_vault_with_price_safety(
            vault_metadata, mock_price_oracle, asset_registry
        )
        if not new_vault_metadata[6]:
            metadata[2] = False
        if not new_vault_metadata[7]:
            metadata[3] = False

    return metadata


def safe_to_execute_outside_epsilon(metadata):
    expected = True
    for vault in metadata[0]:
        if vault[8]:
            continue
        resulting_to_ideal = abs(vault[3] - vault[1])
        current_to_ideal = abs(vault[2] - vault[1])
        if resulting_to_ideal >= current_to_ideal:
            expected = False

    return expected
