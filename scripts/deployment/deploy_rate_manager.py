from scripts.utils import (
    get_deployer,
    make_tx_params,
    with_deployed,
)
from brownie import RateManager, GovernanceProxy
from tests.fixtures.mainnet_contracts import TokenAddresses

from tests.support.types import RateProviderInfo


@with_deployed(GovernanceProxy)
def main(governance_proxy):
    deployer = get_deployer()
    deployer.deploy(
        RateManager,
        governance_proxy,
        **make_tx_params(),
    )


providers_info = [
    RateProviderInfo(
        underlying=TokenAddresses.sDAI,
        provider="0xc7177B6E18c1Abd725F5b75792e5F7A3bA5DBC2c",
    ),
    # RateProviderInfo(
    #     underlying=TokenAddresses.aUSDT,
    #     provider="",
    # ),
    # RateProviderInfo(
    #     underlying=TokenAddresses.fUSDC,
    #     provider="",
    # ),
]


@with_deployed(RateManager)
@with_deployed(GovernanceProxy)
def set_rate_providers(governance_proxy, rate_manager):
    deployer = get_deployer()
    governance_proxy.executeCall(
        rate_manager,
        rate_manager.setRateProviderInfo.encode_input(providers_info),
        {"from": deployer, **make_tx_params()},
    )
