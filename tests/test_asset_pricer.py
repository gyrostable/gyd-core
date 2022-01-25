from decimal import Decimal as D

import pytest

from tests.support.utils import scale

ASSET_1_ADDRESS = "0x827b44d53Df2854057713b25Cdd653Eb70Fe36C4"
ASSET_2_ADDRESS = "0x77952Ce83Ca3cad9F7AdcFabeDA85Bd2F1f52008"

pytestmark = pytest.mark.usefixtures("set_price_oracle_prices")


@pytest.fixture(scope="module")
def set_price_oracle_prices(mock_price_oracle):
    mock_price_oracle.setPrice(ASSET_1_ADDRESS, scale("1.5"))
    mock_price_oracle.setPrice(ASSET_2_ADDRESS, scale("2.5"))


def test_get_usd_value(asset_pricer):
    actual = asset_pricer.getUSDValue((ASSET_1_ADDRESS, scale("3.5")))
    assert actual == scale("1.5") * D("3.5")

    actual = asset_pricer.getUSDValue((ASSET_2_ADDRESS, scale("4.5")))
    assert actual == scale("2.5") * D("4.5")


def test_get_basket_usd_value(asset_pricer):
    actual = asset_pricer.getBasketUSDValue(
        [
            (ASSET_1_ADDRESS, scale("3.2")),
            (ASSET_2_ADDRESS, scale("8.5")),
        ]
    )
    expected = scale("1.5") * D("3.2") + scale("2.5") * D("8.5")
    assert actual == expected
