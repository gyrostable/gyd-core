import pytest
from tests.fixtures.mainnet_contracts import (
    CHAINLINK_FEEDS,
    TokenAddresses,
    UniswapPools,
    is_stable,
)
from tests.support import config_keys, constants
from tests.support.retrieve_coinbase_prices import fetch_prices, find_price
from tests.support.utils import scale


@pytest.fixture(scope="module")
def mainnet_asset_registry(admin, asset_registry):
    asset_registry.setAssetAddress("ETH", TokenAddresses.WETH, {"from": admin})
    asset_registry.setAssetAddress("DAI", TokenAddresses.DAI, {"from": admin})
    asset_registry.setAssetAddress("WBTC", TokenAddresses.WBTC, {"from": admin})
    asset_registry.setAssetAddress("USDC", TokenAddresses.USDC, {"from": admin})
    asset_registry.setAssetAddress("USDT", TokenAddresses.USDT, {"from": admin})

    asset_registry.addStableAsset(TokenAddresses.USDT, {"from": admin})
    asset_registry.addStableAsset(TokenAddresses.USDC, {"from": admin})
    asset_registry.addStableAsset(TokenAddresses.DAI, {"from": admin})

    return asset_registry


@pytest.fixture(scope="module")
def add_common_uniswap_pools(admin, uniswap_v3_twap_oracle):
    pools = [
        getattr(UniswapPools, v) for v in dir(UniswapPools) if not v.startswith("_")
    ]
    for pool in pools:
        uniswap_v3_twap_oracle.registerPool(pool, {"from": admin})


@pytest.fixture(scope="module")
def set_common_chainlink_feeds(
    admin, chainlink_price_oracle, crash_protected_chainlink_oracle
):
    for asset, feed in CHAINLINK_FEEDS:
        chainlink_price_oracle.setFeed(asset, feed, {"from": admin})
        min_diff_time = 3_600
        max_deviation = scale("0.01" if is_stable(asset) else "0.05")
        crash_protected_chainlink_oracle.setFeed(
            asset, feed, (min_diff_time, max_deviation), {"from": admin}
        )


@pytest.fixture(scope="module")
def full_checked_price_oracle(
    admin,
    crash_protected_chainlink_oracle,
    uniswap_v3_twap_oracle,
    coinbase_price_oracle,
    CheckedPriceOracle,
    gyro_config,
):
    mainnet_checked_price_oracle = admin.deploy(
        CheckedPriceOracle, crash_protected_chainlink_oracle, uniswap_v3_twap_oracle
    )
    mainnet_checked_price_oracle.addSignedPriceSource(
        coinbase_price_oracle, {"from": admin}
    )
    mainnet_checked_price_oracle.addQuoteAssetsForPriceLevelTwap(
        TokenAddresses.USDC, {"from": admin}
    )
    mainnet_checked_price_oracle.addQuoteAssetsForPriceLevelTwap(
        TokenAddresses.USDT, {"from": admin}
    )
    mainnet_checked_price_oracle.addQuoteAssetsForPriceLevelTwap(
        TokenAddresses.DAI, {"from": admin}
    )
    gyro_config.setAddress(
        config_keys.ROOT_PRICE_ORACLE_ADDRESS,
        mainnet_checked_price_oracle,
        {"from": admin},
    )
    return mainnet_checked_price_oracle


@pytest.fixture(scope="module")
def coinbase_price_oracle(
    admin, TestingTrustedSignerPriceOracle, mainnet_asset_registry
):
    oracle = admin.deploy(
        TestingTrustedSignerPriceOracle,
        mainnet_asset_registry,
        constants.COINBASE_SIGNING_ADDRESS,
    )

    eth_price = find_price(fetch_prices()[0], "ETH")
    oracle.postPrices([eth_price], {"from": admin})
    return oracle


@pytest.fixture(scope="module")
def full_motherboard(admin, Motherboard, request, gyro_config):
    extra_dependencies = [
        "gyd_token",
        "reserve",
        "fee_bank",
        "set_common_chainlink_feeds",
        "add_common_uniswap_pools",
        "full_checked_price_oracle",
    ]
    for dep in extra_dependencies:
        request.getfixturevalue(dep)
    motherboard = admin.deploy(Motherboard, gyro_config)
    return motherboard
