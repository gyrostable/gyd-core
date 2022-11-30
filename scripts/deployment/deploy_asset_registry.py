from brownie import AssetRegistry  # type: ignore
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
def initialize(asset_registry):
    deployer = get_deployer()
    asset_registry.setAssetAddress("ETH", ETH_ADDRESS, {"from": deployer})
    asset_registry.setAssetAddress("WETH", TokenAddresses.WETH, {"from": deployer})
    asset_registry.setAssetAddress("DAI", TokenAddresses.DAI, {"from": deployer})
    asset_registry.setAssetAddress("WBTC", TokenAddresses.WBTC, {"from": deployer})
    asset_registry.setAssetAddress("USDC", TokenAddresses.USDC, {"from": deployer})
    asset_registry.setAssetAddress("USDT", TokenAddresses.USDT, {"from": deployer})

    asset_registry.addStableAsset(TokenAddresses.USDT, {"from": deployer})
    asset_registry.addStableAsset(TokenAddresses.USDC, {"from": deployer})
    asset_registry.addStableAsset(TokenAddresses.DAI, {"from": deployer})

    return asset_registry


@with_gas_usage
@with_deployed(AssetRegistry)
def proxy(asset_registry):
    deploy_proxy(
        asset_registry,
        config_key=config_keys.ASSET_REGISTRY_ADDRESS,
        init_data=asset_registry.initialize.encode_input(get_deployer()),
    )


@with_gas_usage
@as_singleton(AssetRegistry)
def main():
    deployer = get_deployer()
    deployer.deploy(AssetRegistry, **make_tx_params())
