import pytest

from tests.fixtures.mainnet_contracts import TokenAddresses


TELLOR_ORACLE_ADDRESS = "0x8cFc184c877154a8F9ffE0fe75649dbe5e2DBEbf"


@pytest.fixture(scope="module")
def tellor_oracle(admin, TellorOracle):
    return admin.deploy(
        TellorOracle, TELLOR_ORACLE_ADDRESS, TokenAddresses.WETH, 24 * 86400
    )


@pytest.mark.mainnetFork
def test_tellor_oracle_eth_price(tellor_oracle):
    price = tellor_oracle.getPriceUSD(TokenAddresses.WETH)
    assert 1_000 * 10**18 <= price <= 10_000 * 10**18
