from decimal import Decimal

import pytest
from brownie.test.managers.runner import RevertContextManager as reverts
from tests.fixtures.mainnet_contracts import TokenAddresses
from tests.support import error_codes
from tests.support.utils import scale

ETH_USD_PRICE = scale("2700")
CRV_USD_PRICE = scale("3.5")
USDC_USD_PRICE = scale("1.001")
BTC_USD_PRICE = scale("37324")


@pytest.fixture
def set_dummy_usd_prices(mock_price_oracle):
    mock_price_oracle.setUSDPrice(TokenAddresses.CRV, CRV_USD_PRICE)
    mock_price_oracle.setUSDPrice(TokenAddresses.WETH, ETH_USD_PRICE)
    mock_price_oracle.setUSDPrice(TokenAddresses.USDC, USDC_USD_PRICE)
    mock_price_oracle.setUSDPrice(TokenAddresses.WBTC, BTC_USD_PRICE)


@pytest.mark.usefixtures("set_dummy_usd_prices")
def test_get_price_usd_no_deviation(local_checked_price_oracle, mock_price_oracle):
    mock_price_oracle.setRelativePrice(
        TokenAddresses.CRV, TokenAddresses.WETH, scale(CRV_USD_PRICE / ETH_USD_PRICE)
    )

    crv_usd_price = local_checked_price_oracle.getPriceUSD(TokenAddresses.CRV)

    assert crv_usd_price == CRV_USD_PRICE


@pytest.mark.usefixtures("set_dummy_usd_prices")
def test_get_price_usd_small_deviation(local_checked_price_oracle, mock_price_oracle):
    mock_price_oracle.setRelativePrice(
        TokenAddresses.CRV,
        TokenAddresses.WETH,
        scale(CRV_USD_PRICE / ETH_USD_PRICE) * Decimal("0.9999"),
    )

    crv_usd_price = local_checked_price_oracle.getPriceUSD(TokenAddresses.CRV)

    assert crv_usd_price == CRV_USD_PRICE


@pytest.mark.usefixtures("set_dummy_usd_prices")
def test_get_price_usd_large_deviation(local_checked_price_oracle, mock_price_oracle):
    mock_price_oracle.setRelativePrice(
        TokenAddresses.CRV,
        TokenAddresses.WETH,
        scale(CRV_USD_PRICE / ETH_USD_PRICE) * Decimal("0.9"),
    )

    with reverts(error_codes.STALE_PRICE):
        local_checked_price_oracle.getPriceUSD(TokenAddresses.CRV)


def test_get_prices_no_assets(local_checked_price_oracle):
    with reverts(error_codes.INVALID_ARGUMENT):
        local_checked_price_oracle.getPricesUSD([])


@pytest.mark.usefixtures("set_dummy_usd_prices")
def test_get_prices_usd_no_deviation_one_asset(
    local_checked_price_oracle, mock_price_oracle
):
    mock_price_oracle.setRelativePrice(
        TokenAddresses.CRV, TokenAddresses.WETH, scale(CRV_USD_PRICE / ETH_USD_PRICE)
    )

    usd_prices = local_checked_price_oracle.getPricesUSD([TokenAddresses.CRV])

    assert usd_prices == [CRV_USD_PRICE]


@pytest.mark.usefixtures("set_dummy_usd_prices")
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


@pytest.mark.usefixtures("set_dummy_usd_prices")
def test_get_prices_usd_no_deviation_multiple_assets(
    local_checked_price_oracle, mock_price_oracle
):
    mock_price_oracle.setRelativePrice(
        TokenAddresses.CRV, TokenAddresses.WETH, scale(CRV_USD_PRICE / ETH_USD_PRICE)
    )
    mock_price_oracle.setRelativePrice(
        TokenAddresses.WBTC, TokenAddresses.USDC, scale(BTC_USD_PRICE / USDC_USD_PRICE)
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


@pytest.mark.usefixtures("set_dummy_usd_prices")
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

    usd_prices = local_checked_price_oracle.getPricesUSD(
        [
            TokenAddresses.CRV,
            TokenAddresses.WETH,
            TokenAddresses.WBTC,
            TokenAddresses.USDC,
        ]
    )

    assert usd_prices == [CRV_USD_PRICE, ETH_USD_PRICE, BTC_USD_PRICE, USDC_USD_PRICE]


@pytest.mark.usefixtures("set_dummy_usd_prices")
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
@pytest.mark.usefixtures("add_common_uniswap_pools", "set_common_chainlink_feeds")
def test_get_on_chain_usd_price(mainnet_checked_price_oracle):
    price = mainnet_checked_price_oracle.getPriceUSD(TokenAddresses.CRV)
    assert scale(1) <= price <= scale(10)


@pytest.mark.mainnetFork
@pytest.mark.usefixtures("add_common_uniswap_pools", "set_common_chainlink_feeds")
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

    assert scale(1) <= crv_price <= scale(10)
    assert scale(1_000) <= weth_price <= scale(10_000)
    assert scale(20_000) <= wbtc_price <= scale(100_000)
    assert scale("0.99") <= usdc_price <= scale("1.01")