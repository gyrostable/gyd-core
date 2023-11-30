import pytest
from tests.fixtures.mainnet_contracts import TokenAddresses

from tests.support.types import PricedToken


@pytest.fixture(scope="module")
def generic_vault_price_oracle(
    GenericVaultPriceOracle, admin, gyro_config, rate_manager
):
    return admin.deploy(GenericVaultPriceOracle, gyro_config)


def test_get_pool_token_price_usd_plain_asset(
    generic_vault_price_oracle, usdc, usdc_vault
):
    price = 10**18
    priced_token = PricedToken(tokenAddress=usdc, is_stable=True, price=price)
    token_price = generic_vault_price_oracle.getPoolTokenPriceUSD(
        usdc_vault, [priced_token]
    )
    assert token_price == price


def test_get_pool_token_price_usd_wrapped_asset(
    generic_vault_price_oracle,
    fusdc,
    fusdc_vault,
    usdc,
    rate_manager,
    ConstantRateProvider,
    admin,
):
    rate = 2 * 10**16  # 0.02
    rate_provider = admin.deploy(ConstantRateProvider, rate)
    rate_manager.setRateProviderInfo(fusdc, (usdc, rate_provider))
    assert fusdc_vault.getTokens() == [usdc]
    price = 10**18
    priced_token = PricedToken(tokenAddress=usdc, is_stable=True, price=price)
    token_price = generic_vault_price_oracle.getPoolTokenPriceUSD(
        fusdc_vault, [priced_token]
    )
    # if USDC price is 1, the price of a single fUSDC in USD is equal to the rate
    assert token_price == rate
