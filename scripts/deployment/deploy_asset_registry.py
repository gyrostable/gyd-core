from brownie import GovernanceProxy, AssetRegistry  # type: ignore
from brownie import ETH_ADDRESS

from scripts.utils import (
    as_singleton,
    deploy_proxy,
    get_deployer,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.fixtures.mainnet_contracts import TokenAddresses
from tests.support import config_keys


@with_gas_usage
@with_deployed(AssetRegistry)
@with_deployed(GovernanceProxy)
def initialize(governance_proxy, asset_registry):
    deployer = get_deployer()
    governance_proxy.executeCall(
        asset_registry,
        asset_registry.setAssetAddress.encode_input("ETH", TokenAddresses.WETH),
        {"from": deployer},
    )
    governance_proxy.executeCall(
        asset_registry,
        asset_registry.setAssetAddress.encode_input("WETH", TokenAddresses.WETH),
        {"from": deployer},
    )
    governance_proxy.executeCall(
        asset_registry,
        asset_registry.setAssetAddress.encode_input("DAI", TokenAddresses.DAI),
        {"from": deployer},
    )
    governance_proxy.executeCall(
        asset_registry,
        asset_registry.setAssetAddress.encode_input("WBTC", TokenAddresses.WBTC),
        {"from": deployer},
    )
    governance_proxy.executeCall(
        asset_registry,
        asset_registry.setAssetAddress.encode_input("USDC", TokenAddresses.USDC),
        {"from": deployer},
    )
    governance_proxy.executeCall(
        asset_registry,
        asset_registry.setAssetAddress.encode_input("USDT", TokenAddresses.USDT),
        {"from": deployer},
    )

    governance_proxy.executeCall(
        asset_registry,
        asset_registry.addStableAsset.encode_input(TokenAddresses.USDT),
        {"from": deployer},
    )
    governance_proxy.executeCall(
        asset_registry,
        asset_registry.addStableAsset.encode_input(TokenAddresses.USDC),
        {"from": deployer},
    )
    governance_proxy.executeCall(
        asset_registry,
        asset_registry.addStableAsset.encode_input(TokenAddresses.DAI),
        {"from": deployer},
    )

    return asset_registry


@with_gas_usage
@with_deployed(AssetRegistry)
@with_deployed(GovernanceProxy)
def proxy(governance_proxy, asset_registry):
    deploy_proxy(
        asset_registry,
        config_key=config_keys.ASSET_REGISTRY_ADDRESS,
        init_data=asset_registry.initialize.encode_input(governance_proxy),
    )


@with_gas_usage
@as_singleton(AssetRegistry)
def main():
    deployer = get_deployer()
    deployer.deploy(AssetRegistry, **make_tx_params())
