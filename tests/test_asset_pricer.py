from decimal import Decimal as D

import pytest

from tests.support.utils import scale


@pytest.fixture(scope="module")
def asset_1(Token, admin):
    return admin.deploy(Token, "Asset 1", "A1", 18, scale(10_000))


@pytest.fixture(scope="module")
def asset_2(Token, admin):
    return admin.deploy(Token, "Asset 1", "A1", 18, scale(10_000))


@pytest.fixture(scope="module", autouse=True)
def set_price_oracle_prices(mock_price_oracle, asset_1, asset_2, usdc):
    mock_price_oracle.setUSDPrice(asset_1, scale("1.5"))
    mock_price_oracle.setUSDPrice(asset_2, scale("2.5"))
    mock_price_oracle.setUSDPrice(usdc, scale("1"))


def test_get_usd_value(asset_pricer, asset_1, asset_2):
    actual = asset_pricer.getUSDValue((asset_1, scale("3.5")))
    assert actual == scale("1.5") * D("3.5")

    actual = asset_pricer.getUSDValue((asset_2, scale("4.5")))
    assert actual == scale("2.5") * D("4.5")


def test_get_usd_value_different_scale(asset_pricer, usdc):
    actual = asset_pricer.getUSDValue((usdc, scale(1, usdc.decimals())))
    assert actual == scale(1)


def test_get_basket_usd_value(asset_pricer, asset_1, asset_2):
    actual = asset_pricer.getBasketUSDValue(
        [
            (asset_1, scale("3.2")),
            (asset_2, scale("8.5")),
        ]
    )
    expected = scale("1.5") * D("3.2") + scale("2.5") * D("8.5")
    assert actual == expected
