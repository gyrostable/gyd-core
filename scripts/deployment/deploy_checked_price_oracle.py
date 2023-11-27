from brownie import GovernanceProxy, CheckedPriceOracle, TrustedSignerPriceOracle, MockPriceOracle, ChainlinkPriceOracle, RateManager  # type: ignore
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


@with_gas_usage
@with_deployed(CheckedPriceOracle)
@with_deployed(TrustedSignerPriceOracle)
@with_deployed(GovernanceProxy)
def initialize(governance_proxy, coinbase_price_oracle, checked_price_oracle):
    deployer = get_deployer()
    tx_params = {"from": deployer, **make_tx_params()}
    governance_proxy.executeCall(
        checked_price_oracle,
        checked_price_oracle.addETHPriceOracle.encode_input(coinbase_price_oracle),
        tx_params,
    )

    assets_for_price_level_twap = [
        TokenAddresses.USDC,
        TokenAddresses.USDT,
        TokenAddresses.DAI,
    ]
    for asset in assets_for_price_level_twap:
        governance_proxy.executeCall(
            checked_price_oracle,
            checked_price_oracle.addQuoteAssetsForPriceLevelTwap.encode_input(asset),
            tx_params,
        )

    assets_for_relative_price_check = [
        TokenAddresses.WETH,
        TokenAddresses.USDC,
        TokenAddresses.USDT,
        TokenAddresses.DAI,
        TokenAddresses.LUSD,
    ]

    for asset in assets_for_relative_price_check:
        governance_proxy.executeCall(
            checked_price_oracle,
            checked_price_oracle.addAssetForRelativePriceCheck.encode_input(asset),
            tx_params,
        )

    asset_with_ignorable_relative_prices = [
        TokenAddresses.crvUSD,
        TokenAddresses.GUSD,
        TokenAddresses.USDP,
    ]
    for asset in asset_with_ignorable_relative_prices:
        governance_proxy.executeCall(
            checked_price_oracle,
            checked_price_oracle.addAssetsWithIgnorableRelativePriceCheck.encode_input(
                asset
            ),
            tx_params,
        )


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
        rate_manager,
        TokenAddresses.WETH,
        **make_tx_params()
    )
