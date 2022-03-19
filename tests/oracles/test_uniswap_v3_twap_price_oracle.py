import pytest
from brownie.test.managers.runner import RevertContextManager as reverts
from tests.fixtures.mainnet_contracts import TokenAddresses, UniswapPools
from tests.support import error_codes
from tests.support.utils import scale


def test_set_time_window_length_seconds(uniswap_v3_twap_oracle):
    assert uniswap_v3_twap_oracle.timeWindowLengthSeconds() == 3600
    uniswap_v3_twap_oracle.setTimeWindowLengthSeconds(10_800)
    assert uniswap_v3_twap_oracle.timeWindowLengthSeconds() == 10_800


@pytest.mark.mainnetFork
def test_register_pool(uniswap_v3_twap_oracle):
    tx = uniswap_v3_twap_oracle.registerPool(UniswapPools.USDC_ETH)
    assert len(tx.events["PoolRegistered"]) == 1
    assert tx.events["PoolRegistered"]["assetA"] == TokenAddresses.USDC
    assert tx.events["PoolRegistered"]["assetB"] == TokenAddresses.WETH
    assert tx.events["PoolRegistered"]["pool"] == UniswapPools.USDC_ETH
    assert (
        uniswap_v3_twap_oracle.getPool(TokenAddresses.USDC, TokenAddresses.WETH)
        == UniswapPools.USDC_ETH
    )
    assert uniswap_v3_twap_oracle.getPools() == [UniswapPools.USDC_ETH]


@pytest.mark.mainnetFork
def test_register_pool_twice(uniswap_v3_twap_oracle):
    uniswap_v3_twap_oracle.registerPool(UniswapPools.USDC_ETH)
    with reverts(error_codes.INVALID_ARGUMENT):
        uniswap_v3_twap_oracle.registerPool(UniswapPools.USDC_ETH)


@pytest.mark.mainnetFork
def test_deregister_pool(uniswap_v3_twap_oracle):
    uniswap_v3_twap_oracle.registerPool(UniswapPools.USDC_ETH)
    assert uniswap_v3_twap_oracle.getPools() == [UniswapPools.USDC_ETH]
    tx = uniswap_v3_twap_oracle.deregisterPool(UniswapPools.USDC_ETH)
    assert len(tx.events["PoolDeregistered"]) == 1
    assert tx.events["PoolDeregistered"]["assetA"] == TokenAddresses.USDC
    assert tx.events["PoolDeregistered"]["assetB"] == TokenAddresses.WETH
    assert tx.events["PoolDeregistered"]["pool"] == UniswapPools.USDC_ETH
    assert len(uniswap_v3_twap_oracle.getPools()) == 0


@pytest.mark.mainnetFork
def test_deregister_unregistered_pool(uniswap_v3_twap_oracle):
    with reverts(error_codes.INVALID_ARGUMENT):
        uniswap_v3_twap_oracle.deregisterPool(UniswapPools.USDC_ETH)


@pytest.mark.mainnetFork
def test_get_relative_price_with_seconds(uniswap_v3_twap_oracle):
    uniswap_v3_twap_oracle.registerPool(UniswapPools.USDC_ETH)
    usd_eth_price_5_minutes = uniswap_v3_twap_oracle.getRelativePrice(
        TokenAddresses.USDC, TokenAddresses.WETH, 300
    )
    usd_eth_price_two_hours = uniswap_v3_twap_oracle.getRelativePrice(
        TokenAddresses.USDC, TokenAddresses.WETH, 7200
    )
    assert usd_eth_price_two_hours != usd_eth_price_5_minutes
    # price change should be moderate
    assert abs(1 - usd_eth_price_5_minutes / usd_eth_price_two_hours) < 0.1


@pytest.mark.mainnetFork
@pytest.mark.usefixtures("add_common_uniswap_pools")
def test_get_relative_price(uniswap_v3_twap_oracle):
    eth_usdc_price = uniswap_v3_twap_oracle.getRelativePrice(
        TokenAddresses.WETH, TokenAddresses.USDC
    )
    assert scale(1_000) <= eth_usdc_price <= scale(10_000)

    usdc_eth_price = uniswap_v3_twap_oracle.getRelativePrice(
        TokenAddresses.USDC, TokenAddresses.WETH
    )
    assert usdc_eth_price == scale(1, 36) / eth_usdc_price

    wbtc_usdc_price = uniswap_v3_twap_oracle.getRelativePrice(
        TokenAddresses.WBTC, TokenAddresses.USDC
    )
    usdc_wbtc_price = uniswap_v3_twap_oracle.getRelativePrice(
        TokenAddresses.USDC, TokenAddresses.WBTC
    )
    assert scale(20_000) <= wbtc_usdc_price <= scale(100_000)
    assert usdc_wbtc_price == scale(1, 36) / wbtc_usdc_price
