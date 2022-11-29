from brownie import AssetRegistry, GyroConfig  # type: ignore
from brownie import ETH_ADDRESS

from scripts.utils import (
    as_singleton,
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
@with_deployed(GyroConfig)
@as_singleton(AssetRegistry)
def main(gyro_config):
    deployer = get_deployer()
    asset_registry = deployer.deploy(AssetRegistry, **make_tx_params())
    gyro_config.setAddress(
        config_keys.ASSET_REGISTRY_ADDRESS,
        asset_registry,
        {"from": deployer, **make_tx_params()},
    )
