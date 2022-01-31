from decimal import Decimal as D

import pytest
from brownie.network.state import Chain

chain = Chain()

POOL_ID = "0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080"

pytestmark = pytest.mark.usefixtures("set_data_for_mock_bal_vault")


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


# def test_are_pool_assets_close_to_stated(balancer_safety_checks, mock_balancer_pool, mock_balancer_vault, asset_pricer):
