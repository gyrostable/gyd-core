import json
from brownie import GovernanceProxy, CheckedPriceOracle, TellorOracle, TrustedSignerPriceOracle, MockPriceOracle, ChainlinkPriceOracle, RateManager  # type: ignore
from brownie import chain
from scripts.utils import (
    as_singleton,
    get_deployer,
    is_live,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.fixtures.mainnet_contracts import TokenAddresses
from tests.support.constants import UNISWAP_V3_ORACLE


@with_deployed(TellorOracle)
@with_deployed(CheckedPriceOracle)
@with_deployed(TrustedSignerPriceOracle)
def initialize(coinbase_price_oracle, checked_price_oracle, tellor_oracle):
    calls_data = []

    eth_price_oracles = [coinbase_price_oracle, tellor_oracle]
    for oracle in eth_price_oracles:
        calls_data.append(checked_price_oracle.addETHPriceOracle.encode_input(oracle))

    assets_for_price_level_twap = [
        TokenAddresses.USDC,
        TokenAddresses.USDT,
        TokenAddresses.DAI,
    ]
    for asset in assets_for_price_level_twap:
        calls_data.append(
            checked_price_oracle.addQuoteAssetsForPriceLevelTwap.encode_input(asset)
        )

    assets_for_relative_price_check = [
        TokenAddresses.WETH,
        TokenAddresses.USDC,
        TokenAddresses.USDT,
        TokenAddresses.DAI,
        TokenAddresses.LUSD,
    ]

    for asset in assets_for_relative_price_check:
        calls_data.append(
            checked_price_oracle.addAssetForRelativePriceCheck.encode_input(asset)
        )

    asset_with_ignorable_relative_prices = [
        TokenAddresses.crvUSD,
        TokenAddresses.GUSD,
        TokenAddresses.USDP,
    ]
    for asset in asset_with_ignorable_relative_prices:
        calls_data.append(
            checked_price_oracle.addAssetsWithIgnorableRelativePriceCheck.encode_input(
                asset
            )
        )

    calls = [(checked_price_oracle.address, data) for data in calls_data]
    print(json.dumps(calls))


@with_gas_usage
@as_singleton(CheckedPriceOracle)
@with_deployed(ChainlinkPriceOracle)
@with_deployed(GovernanceProxy)
@with_deployed(RateManager)
def main(rate_manager, governance_proxy, chainlink_oracle):
    deployer = get_deployer()
    if is_live():
        relative_oracle = UNISWAP_V3_ORACLE[chain.id]
    else:
        relative_oracle = MockPriceOracle[0]
    deployer.deploy(
        CheckedPriceOracle,
        governance_proxy,
        chainlink_oracle,
        relative_oracle,
        TokenAddresses.WETH,
        **make_tx_params()
    )
