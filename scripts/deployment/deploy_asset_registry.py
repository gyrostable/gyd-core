from brownie import GovernanceProxy, AssetRegistry, GyroConfig  # type: ignore
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
from tests.support import config_keys, constants


@with_gas_usage
@with_deployed(GyroConfig)
@with_deployed(AssetRegistry)
@with_deployed(GovernanceProxy)
def initialize(governance_proxy, asset_registry, gyro_config):
    asset_registry_address = gyro_config.getAddress(config_keys.ASSET_REGISTRY_ADDRESS)
    deployer = get_deployer()
    governance_proxy.executeCall(
        asset_registry_address,
        asset_registry.setAssetAddress.encode_input("ETH", TokenAddresses.WETH),
        {**make_tx_params(), "from": deployer},
    )
    governance_proxy.executeCall(
        asset_registry_address,
        asset_registry.setAssetAddress.encode_input("WETH", TokenAddresses.WETH),
        {**make_tx_params(), "from": deployer},
    )
    governance_proxy.executeCall(
        asset_registry_address,
        asset_registry.setAssetAddress.encode_input("DAI", TokenAddresses.DAI),
        {**make_tx_params(), "from": deployer},
    )
    governance_proxy.executeCall(
        asset_registry_address,
        asset_registry.setAssetAddress.encode_input("WBTC", TokenAddresses.WBTC),
        {**make_tx_params(), "from": deployer},
    )
    governance_proxy.executeCall(
        asset_registry_address,
        asset_registry.setAssetAddress.encode_input("USDC", TokenAddresses.USDC),
        {**make_tx_params(), "from": deployer},
    )
    governance_proxy.executeCall(
        asset_registry_address,
        asset_registry.setAssetAddress.encode_input("USDT", TokenAddresses.USDT),
        {**make_tx_params(), "from": deployer},
    )

    governance_proxy.executeCall(
        asset_registry_address,
        asset_registry.addStableAsset.encode_input(TokenAddresses.USDT),
        {**make_tx_params(), "from": deployer},
    )
    governance_proxy.executeCall(
        asset_registry_address,
        asset_registry.addStableAsset.encode_input(TokenAddresses.USDC),
        {**make_tx_params(), "from": deployer},
    )
    governance_proxy.executeCall(
        asset_registry_address,
        asset_registry.addStableAsset.encode_input(TokenAddresses.DAI),
        {**make_tx_params(), "from": deployer},
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
@with_deployed(GyroConfig)
def main(gyro_config):
    deployer = get_deployer()
    deployer.deploy(AssetRegistry, gyro_config, **make_tx_params())
