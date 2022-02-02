import pytest
from brownie.test.managers.runner import RevertContextManager as reverts
from tests.support import error_codes
from tests.support.constants import USDC_ADDRESS, WETH_ADDRESS
from tests.support.utils import scale

USDC_ETH_POOL_ADDRESS = "0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8"


def test_set_oracle_seconds_ago(uniswap_v3_twap_oracle):
    assert uniswap_v3_twap_oracle.oracleSecondsAgo() == 10_800
    uniswap_v3_twap_oracle.setTimeWindowLengthSeconds(3600)
    assert uniswap_v3_twap_oracle.oracleSecondsAgo() == 3600


@pytest.mark.mainnetFork
def test_register_pool(uniswap_v3_twap_oracle):
    tx = uniswap_v3_twap_oracle.registerPool(USDC_ETH_POOL_ADDRESS)
    assert len(tx.events["PoolRegistered"]) == 1
    assert tx.events["PoolRegistered"]["assetA"] == USDC_ADDRESS
    assert tx.events["PoolRegistered"]["assetB"] == WETH_ADDRESS
    assert tx.events["PoolRegistered"]["pool"] == USDC_ETH_POOL_ADDRESS
    assert (
        uniswap_v3_twap_oracle.getPool(USDC_ADDRESS, WETH_ADDRESS)
        == USDC_ETH_POOL_ADDRESS
    )
    assert uniswap_v3_twap_oracle.getPools() == [USDC_ETH_POOL_ADDRESS]


@pytest.mark.mainnetFork
def test_register_pool_twice(uniswap_v3_twap_oracle):
    uniswap_v3_twap_oracle.registerPool(USDC_ETH_POOL_ADDRESS)
    with reverts(error_codes.INVALID_ARGUMENT):
        uniswap_v3_twap_oracle.registerPool(USDC_ETH_POOL_ADDRESS)


@pytest.mark.mainnetFork
def test_deregister_pool(uniswap_v3_twap_oracle):
    uniswap_v3_twap_oracle.registerPool(USDC_ETH_POOL_ADDRESS)
    assert uniswap_v3_twap_oracle.getPools() == [USDC_ETH_POOL_ADDRESS]
    tx = uniswap_v3_twap_oracle.deregisterPool(USDC_ETH_POOL_ADDRESS)
    assert len(tx.events["PoolDeregistered"]) == 1
    assert tx.events["PoolDeregistered"]["assetA"] == USDC_ADDRESS
    assert tx.events["PoolDeregistered"]["assetB"] == WETH_ADDRESS
    assert tx.events["PoolDeregistered"]["pool"] == USDC_ETH_POOL_ADDRESS
    assert len(uniswap_v3_twap_oracle.getPools()) == 0


@pytest.mark.mainnetFork
def test_deregister_unregistered_pool(uniswap_v3_twap_oracle):
    with reverts(error_codes.INVALID_ARGUMENT):
        uniswap_v3_twap_oracle.deregisterPool(USDC_ETH_POOL_ADDRESS)


@pytest.mark.mainnetFork
def test_get_relative_price(uniswap_v3_twap_oracle):
    uniswap_v3_twap_oracle.registerPool(USDC_ETH_POOL_ADDRESS)

    eth_usd_price = uniswap_v3_twap_oracle.getRelativePrice(WETH_ADDRESS, USDC_ADDRESS)
    assert eth_usd_price >= scale(1_000)
    assert eth_usd_price <= scale(10_000)  # hopefully this tests by the end of the year

    usd_eth_price = uniswap_v3_twap_oracle.getRelativePrice(USDC_ADDRESS, WETH_ADDRESS)
    assert usd_eth_price == scale(1, 36) / eth_usd_price


@pytest.mark.mainnetFork
def test_get_relative_price_with_seconds(uniswap_v3_twap_oracle):
    uniswap_v3_twap_oracle.registerPool(USDC_ETH_POOL_ADDRESS)
    usd_eth_price_two_hours = uniswap_v3_twap_oracle.getRelativePrice(
        USDC_ADDRESS, WETH_ADDRESS
    )
    usd_eth_price_one_hour = uniswap_v3_twap_oracle.getRelativePrice(
        USDC_ADDRESS, WETH_ADDRESS, 3600
    )
    assert usd_eth_price_two_hours != usd_eth_price_one_hour
    # price change should be moderate
    assert abs(1 - usd_eth_price_one_hour / usd_eth_price_two_hours) < 0.1
