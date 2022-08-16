from brownie import CheckedPriceOracle, TrustedSignerPriceOracle, UniswapV3TwapOracle, CrashProtectedChainlinkPriceOracle  # type: ignore
from scripts.utils import (
    as_singleton,
    get_deployer,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.fixtures.mainnet_contracts import TokenAddresses


@with_gas_usage
@with_deployed(CheckedPriceOracle)
@with_deployed(TrustedSignerPriceOracle)
def initialize(coinbase_price_oracle, checked_price_oracle):
    deployer = get_deployer()
    tx_params = {"from": deployer, **make_tx_params()}
    checked_price_oracle.addSignedPriceSource(coinbase_price_oracle, tx_params)
    checked_price_oracle.addQuoteAssetsForPriceLevelTwap(TokenAddresses.USDC, tx_params)
    checked_price_oracle.addQuoteAssetsForPriceLevelTwap(TokenAddresses.USDT, tx_params)
    checked_price_oracle.addQuoteAssetsForPriceLevelTwap(TokenAddresses.DAI, tx_params)
    checked_price_oracle.addAssetForRelativePriceCheck(TokenAddresses.USDC, tx_params)
    checked_price_oracle.addAssetForRelativePriceCheck(TokenAddresses.WETH, tx_params)


@with_gas_usage
@as_singleton(CheckedPriceOracle)
@with_deployed(UniswapV3TwapOracle)
@with_deployed(CrashProtectedChainlinkPriceOracle)
def main(crash_protected_chainlink_oracle, uniswap_v3_twap_oracle):
    deployer = get_deployer()
    deployer.deploy(
        CheckedPriceOracle,
        crash_protected_chainlink_oracle,
        uniswap_v3_twap_oracle,
        **make_tx_params()
    )
