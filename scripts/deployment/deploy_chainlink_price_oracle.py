import time
from brownie import GovernanceProxy, ChainlinkPriceOracle, CrashProtectedChainlinkPriceOracle  # type: ignore
from brownie import web3, ZERO_ADDRESS

from scripts.utils import (
    get_deployer,
    as_singleton,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.fixtures.mainnet_contracts import get_chainlink_feeds, is_stable
from tests.support.utils import scale


@with_deployed(ChainlinkPriceOracle)
@with_deployed(GovernanceProxy)
def set_feeds(governance_proxy, chainlink_oracle):
    deployer = get_deployer()
    supported_assets = {
        web3.toChecksumAddress(a) for a in chainlink_oracle.listSupportedAssets()
    }
    for asset, feed in get_chainlink_feeds():
        if web3.toChecksumAddress(asset) in supported_assets:
            continue
        governance_proxy.executeCall(
            chainlink_oracle,
            chainlink_oracle.setFeed.encode_input(asset, feed),
            {"from": deployer, **make_tx_params()},
        )


@with_gas_usage
@as_singleton(ChainlinkPriceOracle)
@with_deployed(GovernanceProxy)
def main(governance_proxy):
    return get_deployer().deploy(
        ChainlinkPriceOracle, governance_proxy, **make_tx_params()
    )
