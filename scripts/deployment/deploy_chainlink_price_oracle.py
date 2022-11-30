from brownie import GovernanceProxy, CrashProtectedChainlinkPriceOracle  # type: ignore
from brownie import web3

from scripts.utils import (
    get_deployer,
    as_singleton,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.fixtures.mainnet_contracts import get_chainlink_feeds, is_stable
from tests.support.utils import scale


@with_deployed(CrashProtectedChainlinkPriceOracle)
def set_feeds(crash_protected_chainlink_oracle):
    deployer = get_deployer()
    supported_assets = {
        web3.toChecksumAddress(a)
        for a in crash_protected_chainlink_oracle.listSupportedAssets()
    }
    for asset, feed in get_chainlink_feeds():
        if web3.toChecksumAddress(asset) in supported_assets:
            continue
        min_diff_time = 3_600
        max_deviation = scale("0.01" if is_stable(asset) else "0.05")
        crash_protected_chainlink_oracle.setFeed(
            asset,
            feed,
            (min_diff_time, max_deviation),
            {"from": deployer, **make_tx_params()},
        )


@with_gas_usage
@as_singleton(CrashProtectedChainlinkPriceOracle)
@with_deployed(GovernanceProxy)
def main(governance_proxy):
    return get_deployer().deploy(
        CrashProtectedChainlinkPriceOracle, governance_proxy, **make_tx_params()
    )
