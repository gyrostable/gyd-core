import json
from scripts.utils import (
    get_deployer,
    make_tx_params,
    with_deployed,
)
from brownie import RateManager, GovernanceProxy, ConstantRateProvider
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


def atoken_provider():
    deployer = get_deployer()
    deployer.deploy(ConstantRateProvider, 10**18, **make_tx_params())


providers_info = [
    (
        TokenAddresses.sDAI,
        RateProviderInfo(
            underlying=TokenAddresses.DAI,
            provider="0xc7177B6E18c1Abd725F5b75792e5F7A3bA5DBC2c",
        ),
    ),
    (
        TokenAddresses.fUSDC,
        RateProviderInfo(
            underlying=TokenAddresses.USDC,
            provider="0x8ee79Eb3f37b0ea4544DF2a0b9E228b6fcd8c718",
        ),
    ),
    (
        TokenAddresses.aUSDT,
        RateProviderInfo(
            underlying=TokenAddresses.USDT,
            provider="0x5413E8e572759787FBEcE0A8e8d65EB5188556d8",
        ),
    ),
]


@with_deployed(RateManager)
def set_rate_providers(rate_manager):
    calls = []
    for asset, info in providers_info:
        calls.append(
            (
                rate_manager.address,
                rate_manager.setRateProviderInfo.encode_input(asset, info),
            )
        )
    print(json.dumps(calls))
