import hypothesis.strategies as st
import pytest
from brownie.test import given

from tests.reserve import object_creation
from tests.support import constants
from tests.support.quantized_decimal import QuantizedDecimal as D
from tests.support.utils import scale, to_decimal

MAX_VAULTS = 10


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

CURRENT_BLOCK_NUMBER = 2000


def test_calculate_remaining_blocks(vault_safety_mode):
    remaining_blocks = vault_safety_mode.calculateRemainingBlocks(100, 20)
    assert remaining_blocks == 80


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
def test_store_and_access_directional_flow_data(
    vault_safety_mode,
    order_bundle,
    mock_vaults,
):

    mint_order = object_creation.bundle_to_order(order_bundle, True, mock_vaults)
    vault_addresses = [i.address for i in mock_vaults]
    stored_data = vault_safety_mode.accessDirectionalFlowData(
        vault_addresses, mint_order
    )
    print("Stored data", stored_data)
