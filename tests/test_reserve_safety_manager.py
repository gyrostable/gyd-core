from asyncio import constants
from typing import Iterable, List, Tuple

import hypothesis.strategies as st
import pytest
from brownie.test import given
from numpy import exp

from tests.reserve.reserve_math_implementation import (
    calculate_ideal_weights,
    calculate_weights_and_total,
    check_any_off_peg_vault_would_move_closer_to_ideal_weight,
    update_metadata_with_epsilon_status,
    update_vault_with_price_safety,
)
from tests.support import constants
from tests.support.quantized_decimal import QuantizedDecimal as D
from tests.support.utils import scale, to_decimal

POOL_ID = "0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080"

# pytestmark = pytest.mark.usefixtures("set_data_for_mock_bal_vault")

amount_generator = st.integers(
    min_value=int(scale("0.001")), max_value=int(scale(1_000_000_000))
)
price_generator = st.integers(
    min_value=int(scale("0.001")), max_value=int(scale(1_000_000_000))
)
weight_generator = st.integers(min_value=int(scale("0.001")), max_value=int(scale(1)))

boolean_generator = st.booleans()

stablecoin_price_generator = st.integers(
    min_value=int(scale("0.94")), max_value=int(scale("1.06"))
)


def vault_builder(price_generator, amount_generator, weight_generator):
    persisted_metadata = (price_generator, weight_generator, POOL_ID)
    vault_info = (
        "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
        price_generator,
        persisted_metadata,
        amount_generator,
        weight_generator,
    )
    return (vault_info, amount_generator)


def vault_metadata_builder(
    ideal_weight,
    current_weight,
    resulting_weight,
    delta_weight,
    price,
    all_stablecoins_on_peg,
    all_token_prices_large_enough,
    vault_within_epsilon,
):
    vault_meta_data = (
        constants.BALANCER_POOL_ID,
        ideal_weight,
        current_weight,
        resulting_weight,
        delta_weight,
        price,
        all_stablecoins_on_peg,
        all_token_prices_large_enough,
        vault_within_epsilon,
    )

    return vault_meta_data


def bundle_to_metadata(bundle):
    (
        ideal_weight,
        current_weight,
        resulting_weight,
        delta_weight,
        price,
        all_stablecoins_on_peg,
        all_token_prices_large_enough,
        vault_within_epsilon,
        all_vaults_within_epsilon,
        all_stablecoins_all_vaults_on_peg,
        all_vaults_using_large_enough_prices,
        mint,
    ) = [list(v) for v in zip(*bundle)]

    vaultmetadata = []
    for i in range(len(ideal_weight)):
        vault = vault_metadata_builder(
            ideal_weight[i],
            current_weight[i],
            resulting_weight[i],
            delta_weight[i],
            price[i],
            all_stablecoins_on_peg[i],
            all_token_prices_large_enough[i],
            vault_within_epsilon[i],
        )
        vaultmetadata.append(vault)

    metadata = (
        vaultmetadata,
        all_vaults_within_epsilon[0],
        all_stablecoins_all_vaults_on_peg[0],
        all_vaults_using_large_enough_prices[0],
        mint[0],
    )

    return metadata


@given(amounts_and_prices=st.lists(st.tuples(amount_generator, price_generator)))
def test_calculate_weights_and_total(reserve_safety_manager, amounts_and_prices):
    if not amounts_and_prices:
        return

    amounts, prices = [list(v) for v in zip(*amounts_and_prices)]

    weights_exp, total_exp = calculate_weights_and_total(
        to_decimal(amounts), to_decimal(prices)
    )
    weights_sol, total_sol = reserve_safety_manager.calculateWeightsAndTotal(
        amounts, prices
    )

    approxed_expected_weights = [scale(i).approxed() for i in weights_exp]

    assert to_decimal(weights_sol) == approxed_expected_weights
    assert total_exp == scale(total_sol).approxed()


def bundle_to_vaults(bundle):
    prices, amounts, weights = [list(v) for v in zip(*bundle)]

    vaults_with_amount = []
    for i in range(len(prices)):
        vault = vault_builder(prices[i], amounts[i], weights[i])
        vaults_with_amount.append(vault)

    return vaults_with_amount


@given(bundle=st.lists(st.tuples(price_generator, amount_generator, weight_generator)))
def test_calculate_ideal_weights(reserve_safety_manager, bundle):
    if not bundle:
        return

    vaults_with_amount = bundle_to_vaults(bundle)

    result_exp = calculate_ideal_weights(vaults_with_amount)

    result_sol = reserve_safety_manager.calculateIdealWeights(vaults_with_amount)

    assert scale(result_exp) == to_decimal(result_sol)


@given(
    bundle_metadata=st.lists(
        st.tuples(
            weight_generator,
            weight_generator,
            weight_generator,
            weight_generator,
            price_generator,
            boolean_generator,
            boolean_generator,
            boolean_generator,
            boolean_generator,
            boolean_generator,
            boolean_generator,
            boolean_generator,
        )
    )
)
def test_check_any_off_peg_vault_would_move_closer_to_ideal_weight(
    reserve_safety_manager, bundle_metadata
):
    if not bundle_metadata:
        return
    metadata = bundle_to_metadata(bundle_metadata)

    result_sol = reserve_safety_manager.checkAnyOffPegVaultWouldMoveCloserToIdealWeight(
        metadata
    )
    result_exp = check_any_off_peg_vault_would_move_closer_to_ideal_weight(metadata)

    assert result_sol == result_exp


# @given(bundle=st.lists(st.tuples(price_generator, amount_generator, weight_generator)))
# def test_build_metadata(reserve_safety_manager, bundle):
#     if not bundle:
#         return
#     vaults_with_amount = bundle_to_vaults(bundle)
#     metadata_exp = build_metadata(vaults_with_amount)

#     metadata_sol = reserve_safety_manager.buildMetaData(vaults_with_amount)

#     print("SOL", metadata_sol)
#     print("EXP", metadata_exp)


@given(
    bundle_metadata=st.lists(
        st.tuples(
            weight_generator,
            weight_generator,
            weight_generator,
            weight_generator,
            price_generator,
            boolean_generator,
            boolean_generator,
            boolean_generator,
            boolean_generator,
            boolean_generator,
            boolean_generator,
            boolean_generator,
        )
    )
)
def test_update_metadata_with_epsilon_status(reserve_safety_manager, bundle_metadata):
    if not bundle_metadata:
        return
    metadata = bundle_to_metadata(bundle_metadata)

    result_sol = reserve_safety_manager.updateMetaDataWithEpsilonStatus(metadata)
    result_exp = update_metadata_with_epsilon_status(metadata)

    assert result_sol[1] == result_exp[1]


@given(
    bundle_vault_metadata=st.tuples(
        weight_generator,
        weight_generator,
        weight_generator,
        weight_generator,
        price_generator,
        boolean_generator,
        boolean_generator,
        boolean_generator,
    )
)
def test_update_vault_with_price_safety(
    reserve_safety_manager, bundle_vault_metadata, mock_price_oracle
):
    vault_metadata = vault_metadata_builder(
        bundle_vault_metadata[0],
        bundle_vault_metadata[1],
        bundle_vault_metadata[2],
        bundle_vault_metadata[3],
        bundle_vault_metadata[4],
        bundle_vault_metadata[5],
        bundle_vault_metadata[6],
        bundle_vault_metadata[7],
    )
    vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
        vault_metadata
    )
    vault_metadata_exp = update_vault_with_price_safety(vault_metadata)


def test_update_metadata_with_price_safety():
    pass


def test_safe_to_execute_outside_epsilon():
    pass


def test_is_mint_safe():
    pass


def test_is_redeem_safe():
    pass
