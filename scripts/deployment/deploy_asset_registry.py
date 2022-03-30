from brownie import AssetRegistry  # type: ignore
from scripts.utils import as_singleton, get_deployer, with_deployed, with_gas_usage
from tests.fixtures.mainnet_contracts import TokenAddresses
from tests.support.constants import COINBASE_SIGNING_ADDRESS
from tests.support.retrieve_coinbase_prices import fetch_prices, find_price


@with_gas_usage
@with_deployed(AssetRegistry)
def initialize(asset_registry):
    deployer = get_deployer()
    asset_registry.setAssetAddress("ETH", TokenAddresses.WETH, {"from": deployer})
    asset_registry.setAssetAddress("DAI", TokenAddresses.DAI, {"from": deployer})
    asset_registry.setAssetAddress("WBTC", TokenAddresses.WBTC, {"from": deployer})
    asset_registry.setAssetAddress("USDC", TokenAddresses.USDC, {"from": deployer})
    asset_registry.setAssetAddress("USDT", TokenAddresses.USDT, {"from": deployer})

    asset_registry.addStableAsset(TokenAddresses.USDT, {"from": deployer})
    asset_registry.addStableAsset(TokenAddresses.USDC, {"from": deployer})
    asset_registry.addStableAsset(TokenAddresses.DAI, {"from": deployer})

    return asset_registry


@with_gas_usage
@as_singleton(AssetRegistry)
def main():
    deployer = get_deployer()
    deployer.deploy(AssetRegistry)
