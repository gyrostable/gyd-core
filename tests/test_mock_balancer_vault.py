import pytest

DUMMY_POOL_ADDRESS = "0x32296969Ef14EB0c6d29669C550D4a0449130230"
POOL_ID = "0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080"

DUMMY_POOL_ADDRESS_2 = "0x32296969Ef14EB0c6d29669C550D4a0449130231"
POOL_ID_2 = "0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000087"



def test_get_pool(mock_balancer_vault):
    mock_balancer_vault.storePoolAddress(POOL_ID, DUMMY_POOL_ADDRESS)
    (stored_address, pool_type) = mock_balancer_vault.getPool(
        "0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080"
    )

    assert DUMMY_POOL_ADDRESS == stored_address

    mock_balancer_vault.storePoolAddress(POOL_ID_2, DUMMY_POOL_ADDRESS_2)
    (stored_address, pool_type) = mock_balancer_vault.getPool(
        "0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000087"
    )

    assert DUMMY_POOL_ADDRESS_2 == stored_address
