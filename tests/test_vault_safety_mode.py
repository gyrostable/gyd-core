from random import randint
from hypothesis import settings

import hypothesis.strategies as st
import pytest
from brownie.test import given

from tests.fixtures.deployments import vault
from tests.reserve import object_creation
from tests.support import constants
from tests.support.quantized_decimal import QuantizedDecimal as D
from tests.support.utils import scale, to_decimal

MAX_VAULTS = 10


amount_generator = st.integers(
    min_value=int(scale("0.001")), max_value=int(scale(1_000_000_000))
)
short_flow_memory_generator = st.integers(min_value=1, max_value=1000)
price_generator = st.integers(
    min_value=int(scale("0.001")), max_value=int(scale(1_000_000_000))
)
weight_generator = st.integers(min_value=int(scale("0.001")), max_value=int(scale(1)))

boolean_generator = st.booleans()

stablecoin_price_generator = st.integers(
    min_value=int(scale("0.94")), max_value=int(scale("1.06"))
)

CURRENT_BLOCK_NUMBER = 2000


def test_calculate_remaining_blocks(vault_safety_mode):
    remaining_blocks = vault_safety_mode.calculateRemainingBlocks(100, 20)
    assert remaining_blocks == 80


def build_directional_flow_data(vault_addresses):
    directional_flow_data = []
    for i in range(len(vault_addresses)):
        directional_flow_data.append((randint(3, 30000), randint(5, 29999)))

    return directional_flow_data


@given(
    order_bundle=st.lists(
        st.tuples(
            price_generator,
            weight_generator,
            amount_generator,
            price_generator,
            amount_generator,
            weight_generator,
            weight_generator,
        ),
        min_size=constants.RESERVE_VAULTS,
        max_size=constants.RESERVE_VAULTS,
    ),
)
@settings(max_examples=10)
def test_store_and_access_directional_flow_data_mint(
    vault_safety_mode, order_bundle, mock_vaults, mock_price_oracle
):

    mint_order = object_creation.bundle_to_order(
        order_bundle, True, mock_vaults, mock_price_oracle
    )
    vault_addresses = [i.address for i in mock_vaults]
    stored_data = vault_safety_mode.accessDirectionalFlowData(
        vault_addresses, mint_order
    )

    directional_flow_data = build_directional_flow_data(vault_addresses)
    vault_safety_mode.storeDirectionalFlowData(
        directional_flow_data, mint_order, vault_addresses, 60
    )
    new_stored_data = vault_safety_mode.accessDirectionalFlowData(
        vault_addresses, mint_order
    )

    assert stored_data != new_stored_data

    latest_data = vault_safety_mode.accessDirectionalFlowData(
        vault_addresses, mint_order
    )
    assert latest_data[0][5] == directional_flow_data[5]


@given(
    order_bundle=st.lists(
        st.tuples(
            price_generator,
            weight_generator,
            amount_generator,
            price_generator,
            amount_generator,
            weight_generator,
            weight_generator,
        ),
        min_size=constants.RESERVE_VAULTS,
        max_size=constants.RESERVE_VAULTS,
    ),
)
@settings(max_examples=10)
def test_store_and_access_directional_flow_data_redeem(
    vault_safety_mode, order_bundle, mock_vaults, mock_price_oracle
):

    redeem_order = object_creation.bundle_to_order(
        order_bundle, False, mock_vaults, mock_price_oracle
    )
    vault_addresses = [i.address for i in mock_vaults]
    stored_data = vault_safety_mode.accessDirectionalFlowData(
        vault_addresses, redeem_order
    )

    directional_flow_data = build_directional_flow_data(vault_addresses)
    vault_safety_mode.storeDirectionalFlowData(
        directional_flow_data, redeem_order, vault_addresses, 60
    )
    new_stored_data = vault_safety_mode.accessDirectionalFlowData(
        vault_addresses, redeem_order
    )

    assert stored_data != new_stored_data

    latest_data = vault_safety_mode.accessDirectionalFlowData(
        vault_addresses, redeem_order
    )
    assert latest_data[0][5] == directional_flow_data[5]


@given(
    order_bundle=st.lists(
        st.tuples(
            price_generator,
            weight_generator,
            amount_generator,
            price_generator,
            amount_generator,
            weight_generator,
            weight_generator,
        ),
        min_size=constants.RESERVE_VAULTS,
        max_size=constants.RESERVE_VAULTS,
    ),
)
@settings(max_examples=10)
def test_fetch_latest_directional_flow_data(
    vault_safety_mode, order_bundle, mock_vaults, mock_price_oracle
):

    redeem_order = object_creation.bundle_to_order(
        order_bundle, False, mock_vaults, mock_price_oracle
    )
    vault_addresses = [i.address for i in mock_vaults]

    directional_flow_data = build_directional_flow_data(vault_addresses)
    vault_safety_mode.storeDirectionalFlowData(
        directional_flow_data, redeem_order, vault_addresses, 60
    )

    directional_flow_data_latest = vault_safety_mode.fetchLatestDirectionalFlowData(
        vault_addresses, 100, redeem_order
    )


def update_vault_flow_safety(
    directional_flow_data, proposed_flow_change, short_flow_threshold
):
    allow_transaction = True
    is_safety_mode_activated = False
    if directional_flow_data[1] > 0:
        return (directional_flow_data, False, True)
    new_flow = D(directional_flow_data[0]) + D(proposed_flow_change)
    tuple_as_list = list(directional_flow_data)

    if new_flow > D(short_flow_threshold):
        allow_transaction = False
        tuple_as_list[1] = 100
        directional_flow_data = tuple(tuple_as_list)
    elif new_flow > D(short_flow_threshold) * D("0.8"):
        tuple_as_list[1] = 100
        tuple_as_list[0] += D(new_flow)
        directional_flow_data = tuple(tuple_as_list)
        is_safety_mode_activated = True
    else:
        tuple_as_list[0] += D(new_flow)

    return (directional_flow_data, allow_transaction, is_safety_mode_activated)


@given(
    directional_flow_data=st.tuples(amount_generator, amount_generator),
    proposed_flow_change=amount_generator,
    short_flow_threshold=amount_generator,
)
def test_update_vault_flow_safety(
    vault_safety_mode, directional_flow_data, proposed_flow_change, short_flow_threshold
):
    result_sol = vault_safety_mode.updateVaultFlowSafety(
        directional_flow_data, proposed_flow_change, short_flow_threshold
    )
    result_python = update_vault_flow_safety(
        directional_flow_data, proposed_flow_change, short_flow_threshold
    )
    assert result_sol == result_python


@given(
    order_bundle=st.lists(
        st.tuples(
            price_generator,
            weight_generator,
            amount_generator,
            price_generator,
            amount_generator,
            weight_generator,
            weight_generator,
            short_flow_memory_generator,
            amount_generator,
        ),
        min_size=constants.RESERVE_VAULTS,
        max_size=constants.RESERVE_VAULTS,
    ),
)
def test_flow_safety_state_updater(
    vault_safety_mode, order_bundle, mock_vaults, mock_price_oracle
):
    redeem_order = object_creation.bundle_to_order_vary_persisted(
        order_bundle, False, mock_vaults, mock_price_oracle
    )
    response = vault_safety_mode.flowSafetyStateUpdater(redeem_order)
    assert response[2] == [i.address for i in mock_vaults]
