from decimal import Decimal as D
from multiprocessing import pool

import hypothesis.strategies as st
import pytest
from brownie.test import given
from numpy import exp

POOL_ID = "0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080"

pytestmark = pytest.mark.usefixtures("set_data_for_mock_bal_vault")

balance_strategy = st.integers(min_value=0, max_value=1_000_000_000)


# @pytest.mark.skip()
# @given(balances=st.tuples(balance_strategy, balance_strategy))
# def test_make_monetary_amounts(balancer_safety_checks, dai, usdc, balances):
#     tokens = [dai, usdc]
#     monetary_amounts = balancer_safety_checks.makeMonetaryAmounts(tokens, balances)
#     assert monetary_amounts == [[dai, balances[0]], [usdc, balances[1]]]

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
