import pytest

DUMMY_POOL_ADDRESS = "0x32296969Ef14EB0c6d29669C550D4a0449130230"


def test_get_pool(mock_balancer_vault):
    mock_balancer_vault.storePoolAddress(DUMMY_POOL_ADDRESS)

    assert DUMMY_POOL_ADDRESS == mock_balancer_vault.getPool(
        "0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080"
    )


# def test_get_pool_tokens(mock_balancer_vault):
