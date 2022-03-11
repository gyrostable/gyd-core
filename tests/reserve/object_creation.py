import hypothesis.strategies as st
from tests.support import constants


def vault_lists(*args, **kwargs):
    return st.lists(*args, **kwargs, min_size=1, max_size=constants.RESERVE_VAULTS)


def vault_with_amount_helper(
    price_generator, amount_generator, weight_generator, mock_vault_address
):
    persisted_metadata = (price_generator, weight_generator)
    vault_info = (
        mock_vault_address,
        price_generator,
        persisted_metadata,
        amount_generator,
        weight_generator,
    )
    return (vault_info, amount_generator)


def vault_info_helper(
    price_generator, amount_generator, weight_generator, mock_vault_address
):
    persisted_metadata = (price_generator, weight_generator, 0, 0)
    vault_info = (
        mock_vault_address,
        price_generator,
        persisted_metadata,
        amount_generator,
        weight_generator,
    )
    return vault_info


def bundle_to_metadata(metadata_bundle, mock_vaults):
    vaults_metadata, global_metadata = metadata_bundle
    vaults_metadata = [(mock_vaults[i],) + v for i, v in enumerate(vaults_metadata)]
    return (vaults_metadata,) + global_metadata


def bundle_to_vaults(bundle, mock_vaults):
    prices, amounts, weights = [list(v) for v in zip(*bundle)]

    vaults_with_amount = []
    for i in range(len(prices)):
        vault = vault_with_amount_helper(
            prices[i], amounts[i], weights[i], mock_vaults[i].address
        )
        vaults_with_amount.append(vault)

    return vaults_with_amount


def bundle_to_vault_info(bundle, mock_vaults):
    prices, amounts, weights = [list(v) for v in zip(*bundle)]
    vaults_info = []
    for i in range(len(prices)):
        vault = vault_info_helper(
            prices[i], amounts[i], weights[i], mock_vaults[i].address
        )
        vaults_info.append(vault)

    return vaults_info


def bundle_to_order(order_bundle, mint, mock_vaults):

    (
        initial_prices,
        initial_weights,
        reserve_balances,
        current_vault_prices,
        amounts,
        current_weights,
        ideal_weights,
    ) = [list(v) for v in zip(*order_bundle)]

    return order_builder(
        mint,
        initial_prices,
        initial_weights,
        reserve_balances,
        current_vault_prices,
        amounts,
        current_weights,
        ideal_weights,
        mock_vaults,
    )


def order_builder(
    mint,
    initial_prices,
    initial_weights,
    reserve_balances,
    current_vault_prices,
    amounts,
    current_weights,
    ideal_weights,
    mock_vaults,
):
    vaults_with_amount = []

    for i in range(len(initial_prices)):

        persisted_metadata = (initial_prices[i], initial_weights[i], 0, 0)

        vault_info = (
            mock_vaults[i].address,
            current_vault_prices[i],
            persisted_metadata,
            reserve_balances[i],
            current_weights[i],
            ideal_weights[i],
        )

        vault = (vault_info, amounts[i])
        vaults_with_amount.append(vault)

    return [vaults_with_amount, mint]
