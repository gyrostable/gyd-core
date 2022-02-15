from decimal import Decimal as D
from multiprocessing import pool

POOL_ID = "0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080"


def test_get_pool_id(mock_balancer_pool):
    pool_id = mock_balancer_pool.getPoolId()
    assert pool_id == POOL_ID


def test_unpaused_state(mock_balancer_pool):
    pause_window_end_time = 2000
    buffer_period_end_time = 3000
    mock_balancer_pool.setPausedState(
        False, pause_window_end_time, buffer_period_end_time
    )
    assert (
        False,
        pause_window_end_time,
        buffer_period_end_time,
    ) == mock_balancer_pool.getPausedState()


def test_paused_state(mock_balancer_pool):
    pause_window_end_time = 2000
    buffer_period_end_time = 3000
    mock_balancer_pool.setPausedState(
        True, pause_window_end_time, buffer_period_end_time
    )
    assert (
        True,
        pause_window_end_time,
        buffer_period_end_time,
    ) == mock_balancer_pool.getPausedState()
