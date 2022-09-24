import time

import pytest
from brownie.test.managers.runner import RevertContextManager as reverts

from tests.fixtures.mainnet_contracts import (
    get_chainlink_feeds,
    ChainlinkFeeds,
    TokenAddresses,
)
from tests.support import error_codes
from tests.support.types import FeedMeta
from tests.support.utils import scale

ETH_ADDRESS = TokenAddresses.ETH


MIN_DIFF_TIME = 1800
MAX_DEVIATION = int(scale("0.05"))


@pytest.fixture
def current_time():
    return int(time.time())


@pytest.fixture
def eth_feed(admin, MockChainlinkFeed, crash_protected_chainlink_oracle, current_time):
    feed = admin.deploy(MockChainlinkFeed, 18, scale(2500), current_time)
    crash_protected_chainlink_oracle.setFeed(
        TokenAddresses.ETH,
        feed,
        FeedMeta(min_diff_time=MIN_DIFF_TIME, max_deviation=MAX_DEVIATION),
        {"from": admin},
    )
    return feed


@pytest.fixture
def set_mainnet_feeds(admin, crash_protected_chainlink_oracle):
    for token, feed in get_chainlink_feeds():
        crash_protected_chainlink_oracle.setFeed(
            token,
            feed,
            FeedMeta(min_diff_time=MIN_DIFF_TIME, max_deviation=MAX_DEVIATION),
            {"from": admin},
        )


def test_get_price_no_variation(
    crash_protected_chainlink_oracle, eth_feed, current_time
):
    eth_feed.postRound(scale(2500, 18), current_time + 3600)
    assert crash_protected_chainlink_oracle.getPriceUSD(ETH_ADDRESS) == scale(2500)


def test_get_price_no_variation_multiple_rounds(
    crash_protected_chainlink_oracle, eth_feed, current_time
):
    eth_feed.postRound(scale(3000, 18), current_time + 1500)  # this should be skipped
    eth_feed.postRound(scale(2500, 18), current_time + 1900)
    assert crash_protected_chainlink_oracle.getPriceUSD(ETH_ADDRESS) == scale(2500)


def test_get_price_small_variation(
    crash_protected_chainlink_oracle, eth_feed, current_time
):
    eth_feed.postRound(scale(2600, 18), current_time + 1900)
    assert crash_protected_chainlink_oracle.getPriceUSD(ETH_ADDRESS) == scale(2600)


def test_get_price_too_large_variation(
    crash_protected_chainlink_oracle, eth_feed, current_time
):
    eth_feed.postRound(scale(3000, 18), current_time + 1900)
    with reverts(error_codes.TOO_MUCH_VOLATILITY):
        assert crash_protected_chainlink_oracle.getPriceUSD(ETH_ADDRESS)


@pytest.mark.mainnetFork
@pytest.mark.usefixtures("set_mainnet_feeds")
def test_mainnet_feeds(crash_protected_chainlink_oracle, interface):
    eth_price = crash_protected_chainlink_oracle.getPriceUSD(TokenAddresses.ETH)
    assert scale(1000) <= eth_price <= scale(5000)

    btc_price = crash_protected_chainlink_oracle.getPriceUSD(TokenAddresses.WBTC)
    assert scale(10_000) <= btc_price <= scale(100_000)

    dai_price = crash_protected_chainlink_oracle.getPriceUSD(TokenAddresses.DAI)
    assert scale("0.95") <= dai_price <= scale("1.05")
