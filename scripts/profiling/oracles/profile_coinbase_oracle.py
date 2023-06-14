from decimal import Decimal
import time
from brownie import AssetRegistry, TrustedSignerPriceOracleProfiler  # type: ignore
from brownie import accounts
from scripts.profiling.profiling_utils import comput_gas_stats
from tests.fixtures.mainnet_contracts import TokenAddresses
from tests.support import constants
from tests.support.price_signing import make_message, sign_message
from tests.support.utils import scale

PRICE_DECIMALS = 6


def _make_signed_prices(prices, price_signer):
    return [
        (
            m := make_message(key, int(scale(price, PRICE_DECIMALS))),
            sign_message(m, price_signer),
        )
        for key, price in prices
    ]


def main():
    price_signer = accounts.add(
        "0xb0057716d5917badaf911b193b12b910811c1497b5bada8d7711f758981c3773"
    )

    asset_registry = accounts[0].deploy(
        AssetRegistry, constants.STABLECOIN_MAX_DEVIATION
    )

    admin = accounts[0]

    asset_registry.setAssetAddress("ETH", TokenAddresses.ETH, {"from": admin})
    asset_registry.setAssetAddress("BTC", TokenAddresses.WBTC, {"from": admin})
    asset_registry.setAssetAddress("DAI", TokenAddresses.DAI, {"from": admin})

    prices = [
        ("ETH", Decimal("2395.99")),
        ("BTC", Decimal("38316.7")),
        ("DAI", Decimal("1.013")),
    ]
    signed_prices = _make_signed_prices(prices, price_signer)

    trusted_signer_price_oracle_profiler = accounts[0].deploy(
        TrustedSignerPriceOracleProfiler, asset_registry, price_signer.address, True  # type: ignore
    )

    tx = trusted_signer_price_oracle_profiler.profilePostPrice(
        signed_prices, {"from": accounts[0]}
    )

    gas_stats = comput_gas_stats(tx)

    print("Newly allocated storage")
    print(
        gas_stats["TrustedSignerPriceOracleProfiler.postPrice"].format_with_values(
            signed_prices
        )
    )

    time.sleep(1)

    prices = [
        ("ETH", Decimal("2385.99")),
        ("BTC", Decimal("38216.7")),
        ("DAI", Decimal("1.213")),
    ]
    signed_prices = _make_signed_prices(prices, price_signer)

    tx = trusted_signer_price_oracle_profiler.profilePostPrice(
        signed_prices, {"from": accounts[0]}
    )

    gas_stats = comput_gas_stats(tx)

    print("Already allocated storage")
    print(
        gas_stats["TrustedSignerPriceOracleProfiler.postPrice"].format_with_values(
            signed_prices
        )
    )
