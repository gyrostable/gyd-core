from decimal import Decimal as D
from multiprocessing import pool

import hypothesis.strategies as st
import pytest
from brownie.network.state import Chain
from brownie.test import given

from tests.support.utils import scale, to_decimal

chain = Chain()

POOL_ID = "0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080"

pytestmark = pytest.mark.usefixtures("set_data_for_mock_bal_vault")

balance_strategy = st.integers(min_value=0, max_value=1_000_000_000)


def test_is_pool_paused(
    balancer_safety_checks, mock_balancer_pool, mock_balancer_vault
):
    mock_balancer_pool.setPausedState(False, 2, 4)
    pool_state = balancer_safety_checks.isPoolPaused(POOL_ID)
    assert pool_state == False


def test_is_pool_paused_when_paused(
    balancer_safety_checks, mock_balancer_pool, mock_balancer_vault
):
    mock_balancer_pool.setPausedState(True, 2, 4)
    pool_state = balancer_safety_checks.isPoolPaused(POOL_ID)
    assert pool_state == True


@given(balances=st.tuples(balance_strategy, balance_strategy))
def test_make_monetary_amounts(balancer_safety_checks, dai, usdc, balances):
    tokens = [dai, usdc]
    monetary_amounts = balancer_safety_checks.makeMonetaryAmounts(tokens, balances)
    assert monetary_amounts == [[dai, balances[0]], [usdc, balances[1]]]


@given(balances=st.tuples(balance_strategy, balance_strategy))
def test_get_actual_weights(balancer_safety_checks, dai, usdc, balances):
    tokens = [dai, usdc]
    monetary_amounts = balancer_safety_checks.makeMonetaryAmounts(tokens, balances)
    weights = balancer_safety_checks.getActualWeights(monetary_amounts)

    if (balances[0] == 0) and (balances[1] == 0):
        assert sum(list(weights)) == 0
    else:
        assert sum(list(weights)) == D("1").approxed()
