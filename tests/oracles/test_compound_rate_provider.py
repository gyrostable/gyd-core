import pytest

from tests.fixtures.mainnet_contracts import TokenAddresses


@pytest.fixture(scope="module")
def fusdc_rate_provider(CompoundV2RateProvider, admin):
    return admin.deploy(CompoundV2RateProvider, TokenAddresses.fUSDC)


@pytest.mark.mainnetFork
def test_compound_rate_provider(fusdc_rate_provider):
    # depositing 20 USDC gave ~968 fUSDC
    assert pytest.approx(fusdc_rate_provider.getRate() * 968 / 1e18, abs=1) == 20.0
