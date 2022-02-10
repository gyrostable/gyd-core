from typing import Iterable, List, Tuple

import hypothesis.strategies as st
import pytest
from brownie.test import given
from numpy import exp

from tests.reserve.reserve_math_implementation import (
    calculate_weights_and_total, is_stablecoin_close_to_peg)
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

mint_or_redeem_generator = st.booleans()

stablecoin_price_generator = st.integers(
    min_value=int(scale("0.94")), max_value=int(scale("1.06"))
)



def vault_builder(price_generator, amount_generator, weight_generator, mint_or_redeem_generator):
    persisted_metadata = (price_generator, weight_generator, POOL_ID)
    vault_info = (
        "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
        price_generator,
        persisted_metadata,
        amount_generator,
        weight_generator,
    )
    return {
        "vaultInfo": vault_info,
        "amount": amount_generator,
        "mint": mint_or_redeem_generator,
    }



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


@given(stablecoin_price=stablecoin_price_generator)
def test_is_stablecoin_close_to_peg(reserve_safety_manager, stablecoin_price):
    result_exp = is_stablecoin_close_to_peg(to_decimal(stablecoin_price))
    result_sol = reserve_safety_manager.isStablecoinCloseToPeg(stablecoin_price)

    assert result_exp == result_sol

@given(price_generator = price_generator, amount_generator = amount_generator, weight_generator = weight_generator, mint_or_redeem_generator = mint_or_redeem_generator)
def test_implied_pool_weights(reserve_safety_manager, price_generator, amount_generator, weight_generator, mint_or_redeem_generator):
    vault = vault_builder(price_generator, amount_generator, weight_generator, mint_or_redeem_generator)
    print(vault)
