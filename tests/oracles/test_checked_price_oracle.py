import time
from decimal import Decimal
from statistics import median, median_high, median_low

import hypothesis.strategies as st
import numpy as np
import pytest
import requests
from brownie.test import given
from brownie.test.managers.runner import RevertContextManager as reverts
from tests.fixtures.mainnet_contracts import TokenAddresses
from tests.support import error_codes
from tests.support.price_signing import make_message, sign_message
from tests.support.quantized_decimal import QuantizedDecimal as D
from tests.support.types import RateProviderInfo
from tests.support.utils import scale, to_decimal

ETH_USD_UNSCALED_PRICE = "2700"
ETH_USD_PRICE = scale(ETH_USD_UNSCALED_PRICE)
CRV_USD_PRICE = scale("3.5")
USDC_USD_PRICE = scale("1.001")
BTC_USD_PRICE = scale("37324")

PRICE_DECIMALS = 6


def get_eth_price():
    r = requests.get(
        "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd"
    )
    return r.json()["ethereum"]["usd"]


@pytest.fixture
def initialize_registry(asset_registry, admin):
    asset_registry.setAssetAddress("ETH", TokenAddresses.WETH, {"from": admin})


@pytest.fixture
def initialize_mainnet_oracles(
    mainnet_checked_price_oracle,
    local_signer_price_oracle,
    admin,
    TestingTrustedSignerPriceOracle,
    asset_registry,
    price_signer,
    initialize_registry,
):
    deployed_trusted_signer = admin.deploy(
        TestingTrustedSignerPriceOracle, asset_registry, price_signer, True
    )
    timestamp = int(time.time())
    unscaled_price = D(get_eth_price())
    encoded_message = make_message(
        "ETH", int(scale(unscaled_price, PRICE_DECIMALS)), timestamp
    )
    signature = sign_message(encoded_message, price_signer)

    local_signer_price_oracle.postPrice(encoded_message, signature)

    unscaled_price = unscaled_price * D("0.99")
    encoded_message = make_message(
        "ETH", int(scale(unscaled_price, PRICE_DECIMALS)), timestamp
    )
    signature = sign_message(encoded_message, price_signer)

    deployed_trusted_signer.postPrice(encoded_message, signature)

    mainnet_checked_price_oracle.addETHPriceOracle(local_signer_price_oracle)
    mainnet_checked_price_oracle.addETHPriceOracle(deployed_trusted_signer)
    mainnet_checked_price_oracle.addQuoteAssetsForPriceLevelTwap(TokenAddresses.USDC)

    mainnet_checked_price_oracle.addAssetForRelativePriceCheck(TokenAddresses.WETH)
    mainnet_checked_price_oracle.addAssetForRelativePriceCheck(TokenAddresses.USDC)


def _post_price(oracle, signer, price, timestamp=None):
    if timestamp is None:
        timestamp = int(time.time())
    unscaled_price = D(price)
    encoded_message = make_message(
        "ETH", int(scale(unscaled_price, PRICE_DECIMALS)), timestamp
    )
    signature = sign_message(encoded_message, signer)
    oracle.postPrice(encoded_message, signature)


@pytest.fixture
def initialize_local_oracle(
    local_checked_price_oracle,
    local_signer_price_oracle,
    asset_registry,
    price_signer,
    admin,
):
    asset_registry.setAssetAddress("ETH", TokenAddresses.WETH, {"from": admin})

    _post_price(local_signer_price_oracle, price_signer, ETH_USD_UNSCALED_PRICE)

    local_checked_price_oracle.addETHPriceOracle(local_signer_price_oracle)

    local_checked_price_oracle.addAssetForRelativePriceCheck(TokenAddresses.WETH)
    local_checked_price_oracle.addAssetForRelativePriceCheck(TokenAddresses.USDC)


@pytest.fixture
def set_dummy_usd_prices(mock_price_oracle):
    mock_price_oracle.setUSDPrice(TokenAddresses.CRV, CRV_USD_PRICE)
    mock_price_oracle.setUSDPrice(TokenAddresses.WETH, ETH_USD_PRICE)
    mock_price_oracle.setUSDPrice(TokenAddresses.USDC, USDC_USD_PRICE)
    mock_price_oracle.setUSDPrice(TokenAddresses.WBTC, BTC_USD_PRICE)


@pytest.mark.usefixtures("set_dummy_usd_prices", "initialize_local_oracle")
def test_get_price_usd_no_deviation(local_checked_price_oracle, mock_price_oracle):
    mock_price_oracle.setRelativePrice(
        TokenAddresses.CRV, TokenAddresses.WETH, scale(CRV_USD_PRICE / ETH_USD_PRICE)
    )
    mock_price_oracle.setRelativePrice(
        TokenAddresses.WETH, TokenAddresses.USDC, scale(ETH_USD_PRICE / USDC_USD_PRICE)
    )

    (crv_usd_price, _) = local_checked_price_oracle.getPricesUSD(
        [TokenAddresses.CRV, TokenAddresses.WETH]
    )

    assert crv_usd_price == CRV_USD_PRICE


@pytest.mark.usefixtures("set_dummy_usd_prices", "initialize_local_oracle")
def test_get_price_usd_small_deviation(local_checked_price_oracle, mock_price_oracle):
    mock_price_oracle.setRelativePrice(
        TokenAddresses.CRV,
        TokenAddresses.WETH,
        scale(CRV_USD_PRICE / ETH_USD_PRICE) * Decimal("0.9999"),
    )
    mock_price_oracle.setRelativePrice(
        TokenAddresses.WETH, TokenAddresses.USDC, scale(ETH_USD_PRICE / USDC_USD_PRICE)
    )

    (crv_usd_price, _) = local_checked_price_oracle.getPricesUSD(
        [TokenAddresses.CRV, TokenAddresses.WETH]
    )

    assert crv_usd_price == CRV_USD_PRICE


@pytest.mark.usefixtures("set_dummy_usd_prices", "initialize_local_oracle")
def test_get_price_usd_large_deviation(local_checked_price_oracle, mock_price_oracle):
    mock_price_oracle.setRelativePrice(
        TokenAddresses.CRV,
        TokenAddresses.WETH,
        scale(CRV_USD_PRICE / ETH_USD_PRICE) * Decimal("0.9"),
    )

    with reverts(error_codes.STALE_PRICE):
        local_checked_price_oracle.getPricesUSD(
            [TokenAddresses.CRV, TokenAddresses.WETH]
        )


def test_get_prices_no_assets(local_checked_price_oracle):
    with reverts(error_codes.INVALID_ARGUMENT):
        local_checked_price_oracle.getPricesUSD([])


@pytest.mark.usefixtures("set_dummy_usd_prices", "initialize_local_oracle")
def test_get_prices_usd_multiple_assets_no_reference_point(
    local_checked_price_oracle, mock_price_oracle
):
    mock_price_oracle.setRelativePrice(
        TokenAddresses.CRV, TokenAddresses.WETH, scale(CRV_USD_PRICE / ETH_USD_PRICE)
    )

    with reverts(error_codes.ASSET_NOT_SUPPORTED):
        local_checked_price_oracle.getPricesUSD(
            [
                TokenAddresses.CRV,
                TokenAddresses.WETH,
                TokenAddresses.WBTC,
                TokenAddresses.USDC,
            ]
        )


@pytest.mark.usefixtures("set_dummy_usd_prices", "initialize_local_oracle")
def test_get_prices_usd_multiple_assets_no_reference_point_ignorable(
    local_checked_price_oracle, mock_price_oracle
):
    mock_price_oracle.setRelativePrice(
        TokenAddresses.CRV, TokenAddresses.WETH, scale(CRV_USD_PRICE / ETH_USD_PRICE)
    )
    mock_price_oracle.setRelativePrice(
        TokenAddresses.WETH, TokenAddresses.USDC, scale(ETH_USD_PRICE / USDC_USD_PRICE)
    )
    local_checked_price_oracle.addAssetsWithIgnorableRelativePriceCheck(
        TokenAddresses.WBTC
    )

    usd_prices = local_checked_price_oracle.getPricesUSD(
        [
            TokenAddresses.CRV,
            TokenAddresses.WETH,
            TokenAddresses.WBTC,
            TokenAddresses.USDC,
        ]
    )

    assert usd_prices == [CRV_USD_PRICE, ETH_USD_PRICE, BTC_USD_PRICE, USDC_USD_PRICE]


@pytest.mark.usefixtures("set_dummy_usd_prices", "initialize_local_oracle")
def test_get_prices_usd_no_deviation_multiple_assets(
    local_checked_price_oracle, mock_price_oracle
):
    mock_price_oracle.setRelativePrice(
        TokenAddresses.CRV, TokenAddresses.WETH, scale(CRV_USD_PRICE / ETH_USD_PRICE)
    )
    mock_price_oracle.setRelativePrice(
        TokenAddresses.WBTC, TokenAddresses.USDC, scale(BTC_USD_PRICE / USDC_USD_PRICE)
    )
    mock_price_oracle.setRelativePrice(
        TokenAddresses.WETH, TokenAddresses.USDC, scale(ETH_USD_PRICE / USDC_USD_PRICE)
    )

    usd_prices = local_checked_price_oracle.getPricesUSD(
        [
            TokenAddresses.CRV,
            TokenAddresses.WETH,
            TokenAddresses.WBTC,
            TokenAddresses.USDC,
        ]
    )

    assert usd_prices == [CRV_USD_PRICE, ETH_USD_PRICE, BTC_USD_PRICE, USDC_USD_PRICE]


@pytest.mark.usefixtures("set_dummy_usd_prices", "initialize_local_oracle")
def test_get_prices_usd_small_deviation_multiple_assets(
    local_checked_price_oracle, mock_price_oracle
):
    mock_price_oracle.setRelativePrice(
        TokenAddresses.CRV, TokenAddresses.WETH, scale(CRV_USD_PRICE / ETH_USD_PRICE)
    )
    mock_price_oracle.setRelativePrice(
        TokenAddresses.WBTC,
        TokenAddresses.USDC,
        scale(BTC_USD_PRICE / USDC_USD_PRICE) * Decimal("0.9999"),
    )
    mock_price_oracle.setRelativePrice(
        TokenAddresses.WETH, TokenAddresses.USDC, scale(ETH_USD_PRICE / USDC_USD_PRICE)
    )

    usd_prices = local_checked_price_oracle.getPricesUSD(
        [
            TokenAddresses.CRV,
            TokenAddresses.WETH,
            TokenAddresses.WBTC,
            TokenAddresses.USDC,
        ]
    )

    assert usd_prices == [CRV_USD_PRICE, ETH_USD_PRICE, BTC_USD_PRICE, USDC_USD_PRICE]


@pytest.mark.usefixtures("set_dummy_usd_prices", "initialize_local_oracle")
def test_get_prices_usd_large_deviation_multiple_assets(
    local_checked_price_oracle, mock_price_oracle
):
    mock_price_oracle.setRelativePrice(
        TokenAddresses.CRV, TokenAddresses.WETH, scale(CRV_USD_PRICE / ETH_USD_PRICE)
    )
    mock_price_oracle.setRelativePrice(
        TokenAddresses.WBTC,
        TokenAddresses.USDC,
        scale(BTC_USD_PRICE / USDC_USD_PRICE) * Decimal("0.9"),
    )

    mock_price_oracle.setRelativePrice(
        TokenAddresses.WETH, TokenAddresses.USDC, scale(ETH_USD_PRICE / USDC_USD_PRICE)
    )

    with reverts(error_codes.STALE_PRICE):
        local_checked_price_oracle.getPricesUSD(
            [
                TokenAddresses.CRV,
                TokenAddresses.WETH,
                TokenAddresses.WBTC,
                TokenAddresses.USDC,
            ]
        )


@pytest.mark.mainnetFork
@pytest.mark.usefixtures(
    "set_common_chainlink_feeds",
    "initialize_mainnet_oracles",
)
def test_get_on_chain_usd_prices(mainnet_checked_price_oracle):
    prices = mainnet_checked_price_oracle.getPricesUSD(
        [
            TokenAddresses.CRV,
            TokenAddresses.WETH,
            TokenAddresses.WBTC,
            TokenAddresses.USDC,
        ]
    )
    crv_price, weth_price, wbtc_price, usdc_price = prices

    assert scale("0.2") <= crv_price <= scale(5)
    assert scale(800) <= weth_price <= scale(10_000)
    assert scale(15_000) <= wbtc_price <= scale(100_000)
    assert scale("0.99") <= usdc_price <= scale("1.01")


@given(
    values=st.lists(st.integers(min_value=0, max_value=1e30), min_size=15, max_size=100)
)
def test_median(testing_checked_price_oracle, values):
    median_sol = testing_checked_price_oracle.median(values)
    true_median = median(values)

    if not median_sol == int(true_median):
        assert median_sol == int(true_median) + 1
    else:
        assert median_sol == int(true_median)


@given(
    values=st.lists(
        st.integers(min_value=1, max_value=2**63 - 1), min_size=1, max_size=100
    )
)
def test_medianize_twaps(testing_checked_price_oracle, values):
    medianized = testing_checked_price_oracle.computeMinOrSecondMin(values)

    array = np.array(values, dtype=np.int64)
    print("Array", array)
    if len(array) == 1:
        result = values[0]
    elif len(array) == 2:
        result = np.partition(array, 0)[0]
    else:
        result = np.partition(array, 1)[1]

    assert medianized == result


@pytest.mark.usefixtures("initialize_registry")
def test_single_eth_price_oracle(
    local_checked_price_oracle, local_signer_price_oracle, price_signer
):
    _post_price(local_signer_price_oracle, price_signer, ETH_USD_UNSCALED_PRICE)
    local_checked_price_oracle.addETHPriceOracle(local_signer_price_oracle)
    assert local_checked_price_oracle.getETHPrices() == [ETH_USD_PRICE]


@pytest.mark.usefixtures("initialize_registry")
def test_multiple_eth_price_oracle(
    local_checked_price_oracle,
    local_signer_price_oracle,
    price_signer,
    TestingTrustedSignerPriceOracle,
    asset_registry,
    admin,
):
    _post_price(local_signer_price_oracle, price_signer, ETH_USD_UNSCALED_PRICE)

    other_oracle = admin.deploy(
        TestingTrustedSignerPriceOracle, asset_registry, price_signer, True
    )
    _post_price(other_oracle, price_signer, "2100")

    local_checked_price_oracle.addETHPriceOracle(local_signer_price_oracle)
    local_checked_price_oracle.addETHPriceOracle(other_oracle)

    assert local_checked_price_oracle.getETHPrices() == [ETH_USD_PRICE, scale("2100")]


@pytest.mark.usefixtures("initialize_registry")
def test_all_failing_eth_oracle(
    local_checked_price_oracle,
    price_signer,
    TestingTrustedSignerPriceOracle,
    asset_registry,
    chain,
    admin,
):
    oracle = admin.deploy(
        TestingTrustedSignerPriceOracle, asset_registry, price_signer, True
    )
    local_checked_price_oracle.addETHPriceOracle(oracle)

    _post_price(oracle, price_signer, "2100")
    chain.sleep(3670)

    with reverts(error_codes.NO_WETH_PRICE):
        local_checked_price_oracle.getETHPrices.transact()


@pytest.mark.usefixtures("initialize_registry")
def test_some_failing_eth_oracle(
    local_checked_price_oracle,
    local_signer_price_oracle,
    price_signer,
    TestingTrustedSignerPriceOracle,
    asset_registry,
    chain,
    admin,
):
    failing_oracle = admin.deploy(
        TestingTrustedSignerPriceOracle, asset_registry, price_signer, True
    )
    _post_price(failing_oracle, price_signer, "2100")
    local_checked_price_oracle.addETHPriceOracle(failing_oracle)
    local_checked_price_oracle.addETHPriceOracle(local_signer_price_oracle)

    chain.sleep(3670)

    # post new price so that one of the oracles is not stale
    _post_price(
        local_signer_price_oracle,
        price_signer,
        ETH_USD_UNSCALED_PRICE,
        timestamp=chain.time(),
    )

    assert local_checked_price_oracle.getETHPrices() == [ETH_USD_PRICE]
