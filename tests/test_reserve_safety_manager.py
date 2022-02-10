from typing import Iterable, Tuple

import hypothesis.strategies as st
import pytest
from brownie.test import given
from numpy import exp

from tests.support.quantized_decimal import QuantizedDecimal as D
from tests.support.utils import scale, to_decimal

# POOL_ID = "0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080"

# pytestmark = pytest.mark.usefixtures("set_data_for_mock_bal_vault")

amount_generator = st.integers(min_value=scale("0.001"), max_value=scale(1_000_000_000))
price_generator = st.integers(min_value=scale("0.001"), max_value=scale(1_000_000_000))

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


@given(amounts_and_prices=st.lists(st.tuples(amount_generator, price_generator)))
def test_calculate_weights_and_total(reserve_safety_manager, amounts_and_prices):
    amounts = []
    prices = []
    for i in amounts_and_prices:
        to_decimal(amounts.append(i[0]))
        to_decimal(prices.append(i[1]))

    weights, total = calculate_weights_and_total(amounts, prices)
    print(scale(weights))
    print(scale(total))

    weights_sol, total_sol = reserve_safety_manager.calculateWeightsAndTotal(amounts, prices)

    print(to_decimal(weights), to_decimal(total))




# @pytest.mark.skip()
# @given(balances=st.tuples(balance_strategy, balance_strategy))
# def test_compute_actual_weights(balancer_safety_checks, dai, usdc, balances):
#     tokens = [dai, usdc]
#     monetary_amounts = balancer_safety_checks.makeMonetaryAmounts(tokens, balances)
#     weights = balancer_safety_checks.computeActualWeights(monetary_amounts)

#     if (balances[0] == 0) and (balances[1] == 0):
#         assert sum(list(weights)) == 0
#     else:
#         # Precision error
#         return
#         # assert sum(list(weights)) == int(1e18)

# # @pytest.mark.skip()
# def test_are_pool_weights_close_to_expected_imbalanced(
#     balancer_safety_checks, dai, usdc, mock_balancer_pool, mock_balancer_vault
# ):
#     tokens = [dai, usdc]
#     balances = [3e20, 2e20]
#     mock_balancer_vault.setPoolTokens(POOL_ID, tokens, balances)
#     mock_balancer_pool.setNormalizedWeights([5e17, 5e17])

#     assert balancer_safety_checks.arePoolAssetWeightsCloseToExpected(POOL_ID) == False

# # @pytest.mark.skip()
# def test_are_pool_weights_close_to_expected_exact(
#     balancer_safety_checks, dai, usdc, mock_balancer_pool, mock_balancer_vault
# ):
#     tokens = [dai, usdc]
#     balances = [2e20, 2e20]
#     mock_balancer_vault.setPoolTokens(POOL_ID, tokens, balances)
#     mock_balancer_pool.setNormalizedWeights([5e17, 5e17])

#     assert balancer_safety_checks.arePoolAssetWeightsCloseToExpected(POOL_ID) == True
