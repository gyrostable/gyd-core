import pytest

from tests.fixtures.mainnet_contracts import TokenAddresses


TELLOR_ORACLE_ADDRESS = "0xD9157453E2668B2fc45b7A803D3FEF3642430cC0"


@pytest.fixture(scope="module")
def tellor_oracle(admin, TellorOracle):
    return admin.deploy(TellorOracle, TELLOR_ORACLE_ADDRESS, TokenAddresses.WETH)


@pytest.mark.mainnetFork
def test_tellor_oracle_eth_price(tellor_oracle):
    price = tellor_oracle.getPriceUSD(TokenAddresses.WETH)
    assert 1_000 * 10**18 <= price <= 10_000 * 10**18
