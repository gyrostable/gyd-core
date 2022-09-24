import time

import brownie
import pytest
from tests.fixtures.mainnet_contracts import ChainlinkFeeds, TokenAddresses
from tests.support import error_codes
from tests.support.utils import scale


def test_set_feed(admin, chainlink_price_oracle):
    assert chainlink_price_oracle.feeds(TokenAddresses.ETH) == brownie.ZERO_ADDRESS
    chainlink_price_oracle.setFeed(
        TokenAddresses.ETH, ChainlinkFeeds.ETH_USD_FEED, {"from": admin}
    )
    assert (
        chainlink_price_oracle.feeds(TokenAddresses.ETH) == ChainlinkFeeds.ETH_USD_FEED
    )


def test_fails_non_existent_asset(chainlink_price_oracle):
    with brownie.reverts(error_codes.ASSET_NOT_SUPPORTED):  # type: ignore
        chainlink_price_oracle.getPriceUSD(TokenAddresses.ETH)


def test_fails_negative_price(admin, chainlink_price_oracle, MockChainlinkFeed):
    feed = admin.deploy(MockChainlinkFeed, 8, -1, int(time.time()))
    chainlink_price_oracle.setFeed(TokenAddresses.ETH, feed, {"from": admin})
    with brownie.reverts(error_codes.NEGATIVE_PRICE):  # type: ignore
        chainlink_price_oracle.getPriceUSD(TokenAddresses.ETH)


def test_fails_stale_price(admin, chainlink_price_oracle, MockChainlinkFeed):
    feed = admin.deploy(
        MockChainlinkFeed, 8, scale(2500, 8), int(time.time()) - 100_000
    )
    chainlink_price_oracle.setFeed(TokenAddresses.ETH, feed, {"from": admin})
    with brownie.reverts(error_codes.STALE_PRICE):  # type: ignore
        chainlink_price_oracle.getPriceUSD(TokenAddresses.ETH)


def test_get_price_same_scale(admin, chainlink_price_oracle, MockChainlinkFeed):
    feed = admin.deploy(MockChainlinkFeed, 18, scale(2500, 18), int(time.time()))
    chainlink_price_oracle.setFeed(TokenAddresses.ETH, feed, {"from": admin})
    assert chainlink_price_oracle.getPriceUSD(TokenAddresses.ETH) == scale(2500, 18)


def test_get_price_lower_scale(admin, chainlink_price_oracle, MockChainlinkFeed):
    feed = admin.deploy(MockChainlinkFeed, 8, scale(2500, 8), int(time.time()))
    chainlink_price_oracle.setFeed(TokenAddresses.ETH, feed, {"from": admin})
    assert chainlink_price_oracle.getPriceUSD(TokenAddresses.ETH) == scale(2500, 18)


def test_get_price_higher_scale(admin, chainlink_price_oracle, MockChainlinkFeed):
    feed = admin.deploy(MockChainlinkFeed, 27, scale(2500, 27), int(time.time()))
    chainlink_price_oracle.setFeed(TokenAddresses.ETH, feed, {"from": admin})
    assert chainlink_price_oracle.getPriceUSD(TokenAddresses.ETH) == scale(2500, 18)


@pytest.mark.mainnetFork
@pytest.mark.usefixtures("set_common_chainlink_feeds")
def test_mainnet_feeds(chainlink_price_oracle):
    eth_price = chainlink_price_oracle.getPriceUSD(TokenAddresses.ETH)
    assert scale(1000) <= eth_price <= scale(5000)

    btc_price = chainlink_price_oracle.getPriceUSD(TokenAddresses.WBTC)
    assert scale(10_000) <= btc_price <= scale(100_000)

    dai_price = chainlink_price_oracle.getPriceUSD(TokenAddresses.DAI)
    assert scale("0.95") <= dai_price <= scale("1.05")
