from brownie import GovernanceProxy, CheckedPriceOracle, TrustedSignerPriceOracle, UniswapV3TwapOracle, CrashProtectedChainlinkPriceOracle  # type: ignore
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
@with_deployed(GovernanceProxy)
def initialize(governance_proxy, coinbase_price_oracle, checked_price_oracle):
    deployer = get_deployer()
    tx_params = {"from": deployer, **make_tx_params()}
    governance_proxy.executeCall(
        checked_price_oracle,
        checked_price_oracle.addSignedPriceSource.encode_input(coinbase_price_oracle),
        tx_params,
    )
    governance_proxy.executeCall(
        checked_price_oracle,
        checked_price_oracle.addQuoteAssetsForPriceLevelTwap.encode_input(
            TokenAddresses.USDC
        ),
        tx_params,
    )
    governance_proxy.executeCall(
        checked_price_oracle,
        checked_price_oracle.addQuoteAssetsForPriceLevelTwap.encode_input(
            TokenAddresses.USDT
        ),
        tx_params,
    )
    governance_proxy.executeCall(
        checked_price_oracle,
        checked_price_oracle.addQuoteAssetsForPriceLevelTwap.encode_input(
            TokenAddresses.DAI
        ),
        tx_params,
    )
    governance_proxy.executeCall(
        checked_price_oracle,
        checked_price_oracle.addAssetForRelativePriceCheck.encode_input(
            TokenAddresses.USDC
        ),
        tx_params,
    )
    governance_proxy.executeCall(
        checked_price_oracle,
        checked_price_oracle.addAssetForRelativePriceCheck.encode_input(
            TokenAddresses.WETH
        ),
        tx_params,
    )


@with_gas_usage
@as_singleton(CheckedPriceOracle)
@with_deployed(UniswapV3TwapOracle)
@with_deployed(CrashProtectedChainlinkPriceOracle)
@with_deployed(GovernanceProxy)
def main(governance_proxy, crash_protected_chainlink_oracle, uniswap_v3_twap_oracle):
    deployer = get_deployer()
    deployer.deploy(
        CheckedPriceOracle,
        governance_proxy,
        crash_protected_chainlink_oracle,
        uniswap_v3_twap_oracle,
        TokenAddresses.WETH,
        **make_tx_params()
    )
