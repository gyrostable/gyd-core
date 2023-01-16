from brownie import GovernanceProxy, CheckedPriceOracle, TrustedSignerPriceOracle, MockPriceOracle, CrashProtectedChainlinkPriceOracle  # type: ignore
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
    checked_price_oracle = CheckedPriceOracle.at(
        "0xFEfEEE9ED22B243E8CD52fA353172C3d44fFB434"
    )
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
@with_deployed(CrashProtectedChainlinkPriceOracle)
@with_deployed(GovernanceProxy)
def main(governance_proxy, crash_protected_chainlink_oracle):
    deployer = get_deployer()
    if is_live():
        relative_oracle = UNISWAP_V3_ORACLE
    else:
        relative_oracle = MockPriceOracle[0]
    deployer.deploy(
        CheckedPriceOracle,
        governance_proxy,
        crash_protected_chainlink_oracle,
        relative_oracle,
        TokenAddresses.WETH,
        **make_tx_params()
    )
