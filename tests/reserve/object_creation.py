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


def bundle_to_metadata(
    metadata_bundle, mock_vaults, mock_price_oracle, token_stables=None
):
    vaults_bundle, global_metadata = metadata_bundle
    vaults_metadata = []
    for i, v in enumerate(vaults_bundle):
        tokens = mock_vaults[i].getTokens()
        prices = mock_price_oracle.getPricesUSD(tokens)
        if token_stables is None:
            token_stables = [False] * len(tokens)
        token_with_prices = list(zip(tokens, token_stables, prices))
        vaults_metadata.append((mock_vaults[i],) + v + (token_with_prices,))
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


def bundle_to_order(
    order_bundle, mint, mock_vaults, mock_price_oracle, stable_assets=None
):

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
        mock_price_oracle,
        stable_assets,
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
    mock_price_oracle,
    stable_assets=None,
):
    vaults_with_amount = []

    for i in range(len(initial_prices)):

        persisted_metadata = (
            initial_prices[i],
            initial_weights[i],
            0,
            0,
        )
        vault = mock_vaults[i]

        tokens = vault.getTokens()
        prices = mock_price_oracle.getPricesUSD(tokens)
        if stable_assets is None:
            stable_assets = [False] * len(tokens)
        token_with_prices = list(zip(tokens, stable_assets, prices))
        underlying = vault.underlying()

        vault_info = (
            mock_vaults[i].address,
            18,
            underlying,
            current_vault_prices[i],
            persisted_metadata,
            reserve_balances[i],
            current_weights[i],
            ideal_weights[i],
            token_with_prices,
        )

        vault = (vault_info, amounts[i])
        vaults_with_amount.append(vault)

    return [vaults_with_amount, mint]


def bundle_to_order_vary_persisted(order_bundle, mint, mock_vaults, mock_price_oracle):

    (
        initial_prices,
        initial_weights,
        reserve_balances,
        current_vault_prices,
        amounts,
        current_weights,
        ideal_weights,
        short_flow_memory,
        short_flow_threshold,
    ) = [list(v) for v in zip(*order_bundle)]

    return order_builder_vary_persisted(
        mint,
        initial_prices,
        initial_weights,
        reserve_balances,
        current_vault_prices,
        amounts,
        current_weights,
        ideal_weights,
        mock_vaults,
        short_flow_memory,
        short_flow_threshold,
        mock_price_oracle,
    )


def order_builder_vary_persisted(
    mint,
    initial_prices,
    initial_weights,
    reserve_balances,
    current_vault_prices,
    amounts,
    current_weights,
    ideal_weights,
    mock_vaults,
    short_flow_memory,
    short_flow_threshold,
    mock_price_oracle,
):
    vaults_with_amount = []

    for i in range(len(initial_prices)):

        persisted_metadata = (
            initial_prices[i],
            initial_weights[i],
            short_flow_memory[i],
            short_flow_threshold[i],
        )

        tokens = mock_vaults[i].getTokens()
        prices = mock_price_oracle.getPricesUSD(tokens)
        token_with_prices = list(zip(tokens, [False] * len(tokens), prices))
        underlying = mock_vaults[i].underlying()

        vault_info = (
            mock_vaults[i].address,
            18,
            underlying,
            current_vault_prices[i],
            persisted_metadata,
            reserve_balances[i],
            current_weights[i],
            ideal_weights[i],
            token_with_prices,
        )

        vault = (vault_info, amounts[i])
        vaults_with_amount.append(vault)

    return [vaults_with_amount, mint]
