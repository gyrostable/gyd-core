from brownie import CheckedPriceOracle, TrustedSignerPriceOracle, UniswapV3TwapOracle, CrashProtectedChainlinkPriceOracle  # type: ignore
from scripts.utils import as_singleton, get_deployer, with_deployed, with_gas_usage
from tests.fixtures.mainnet_contracts import TokenAddresses


@with_gas_usage
@with_deployed(CheckedPriceOracle)
@with_deployed(TrustedSignerPriceOracle)
def initialize(coinbase_price_oracle, checked_price_oracle):
    deployer = get_deployer()
    checked_price_oracle.addSignedPriceSource(coinbase_price_oracle, {"from": deployer})
    checked_price_oracle.addQuoteAssetsForPriceLevelTwap(
        TokenAddresses.USDC, {"from": deployer}
    )
    checked_price_oracle.addQuoteAssetsForPriceLevelTwap(
        TokenAddresses.USDT, {"from": deployer}
    )
    checked_price_oracle.addQuoteAssetsForPriceLevelTwap(
        TokenAddresses.DAI, {"from": deployer}
    )


@with_gas_usage
@as_singleton(TrustedSignerPriceOracle)
@with_deployed(UniswapV3TwapOracle)
@with_deployed(CrashProtectedChainlinkPriceOracle)
def main(crash_protected_chainlink_oracle, uniswap_v3_twap_oracle):
    deployer = get_deployer()
    deployer.deploy(
        CheckedPriceOracle, crash_protected_chainlink_oracle, uniswap_v3_twap_oracle
    )
