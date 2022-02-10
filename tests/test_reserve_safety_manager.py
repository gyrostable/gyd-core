from decimal import Decimal as D
from multiprocessing import pool

import hypothesis.strategies as st
import pytest
from brownie.test import given
from numpy import exp

from tests.support.utils import scale

POOL_ID = "0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080"

pytestmark = pytest.mark.usefixtures("set_data_for_mock_bal_vault")

amount_generator = st.integers(min_value=scale("0.1"), max_value=scale(1_000_000_000))
price_generator = st.integers(min_value=scale("0.1"), max_value=scale(1_000_000_000))


@given(amounts_and_prices=st.lists(st.tuples(amount_generator, price_generator)))
def test_calculate_weights_and_total(reserve_safety_manager, amounts_and_prices):
    amounts, prices = amounts_and_prices
    print(amounts)
    print(prices)    

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
