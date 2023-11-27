import brownie
from brownie.test.managers.runner import RevertContextManager as reverts
from tests.support import error_codes
from tests.support.types import Range
from tests.support.utils import format_to_bytes, scale
from tests.fixtures.mainnet_contracts import TokenAddresses


def test_set_asset_address(asset_registry):
    assert len(asset_registry.getRegisteredAssetNames()) == 0
    assert len(asset_registry.getRegisteredAssetAddresses()) == 0
    assert len(asset_registry.getStableAssets()) == 0
    assert not asset_registry.isAssetNameRegistered("BTC")
    asset_registry.setAssetAddress("BTC", TokenAddresses.WBTC)
    assert asset_registry.isAssetNameRegistered("BTC")
    assert asset_registry.isAssetAddressRegistered(TokenAddresses.WBTC)
    assert not asset_registry.isAssetStable(TokenAddresses.WBTC)
    assert asset_registry.getRegisteredAssetNames() == (
        format_to_bytes("BTC", 32, output_hex=True),
    )
    assert asset_registry.getRegisteredAssetAddresses() == (TokenAddresses.WBTC,)
    assert asset_registry.getAssetAddress("BTC") == TokenAddresses.WBTC
    assert len(asset_registry.getStableAssets()) == 0


def test_add_stable_non_existent_asset(asset_registry):
    with reverts(error_codes.ASSET_NOT_SUPPORTED):
        asset_registry.addStableAsset(TokenAddresses.WBTC)


def test_add_stable_asset(asset_registry):
    assert not asset_registry.isAssetStable(TokenAddresses.DAI)
    asset_registry.setAssetAddress("DAI", TokenAddresses.DAI)
    assert not asset_registry.isAssetStable(TokenAddresses.DAI)
    tx = asset_registry.addStableAsset(TokenAddresses.DAI)
    assert tx.events["StableAssetAdded"]["asset"] == TokenAddresses.DAI
    assert asset_registry.isAssetStable(TokenAddresses.DAI)
    assert asset_registry.getStableAssets() == (TokenAddresses.DAI,)


def test_remove_stable_asset(asset_registry):
    asset_registry.setAssetAddress("DAI", TokenAddresses.DAI)
    asset_registry.addStableAsset(TokenAddresses.DAI)
    assert asset_registry.isAssetStable(TokenAddresses.DAI)
    tx = asset_registry.removeStableAsset(TokenAddresses.DAI)
    assert tx.events["StableAssetRemoved"]["asset"] == TokenAddresses.DAI
    assert not asset_registry.isAssetStable(TokenAddresses.DAI)
    assert len(asset_registry.getStableAssets()) == 0


def test_set_asset_address_fails_with_zero_address(asset_registry):
    with reverts(error_codes.INVALID_ARGUMENT):
        asset_registry.setAssetAddress("BTC", brownie.ZERO_ADDRESS)


def test_set_asset_address_fails_without_authorization(asset_registry, alice):
    with reverts(error_codes.NOT_AUTHORIZED):
        asset_registry.setAssetAddress("BTC", TokenAddresses.WBTC, {"from": alice})


def test_add_stable_asset_fails_without_authorization(asset_registry, admin, alice):
    asset_registry.setAssetAddress("DAI", TokenAddresses.DAI, {"from": admin})
    with reverts(error_codes.NOT_AUTHORIZED):
        asset_registry.addStableAsset(TokenAddresses.DAI, {"from": alice})


def test_remove_stable_asset_fails_without_authorization(asset_registry, admin, alice):
    asset_registry.setAssetAddress("DAI", TokenAddresses.DAI, {"from": admin})
    asset_registry.addStableAsset(TokenAddresses.DAI, {"from": admin})
    with reverts(error_codes.NOT_AUTHORIZED):
        asset_registry.removeStableAsset(TokenAddresses.DAI, {"from": alice})


def test_remove_asset(asset_registry):
    asset_registry.setAssetAddress("DAI", TokenAddresses.DAI)
    asset_registry.addStableAsset(TokenAddresses.DAI)
    assert asset_registry.isAssetNameRegistered("DAI")
    assert asset_registry.isAssetStable(TokenAddresses.DAI)
    asset_registry.removeAsset("DAI")
    assert len(asset_registry.getRegisteredAssetNames()) == 0
    assert len(asset_registry.getRegisteredAssetAddresses()) == 0
    assert not asset_registry.isAssetNameRegistered("DAI")
    assert not asset_registry.isAssetAddressRegistered(TokenAddresses.DAI)
    assert not asset_registry.isAssetStable(TokenAddresses.DAI)


def test_inexistent_asset_range(asset_registry):
    asset_registry.setAssetAddress("DAI", TokenAddresses.DAI)
    with reverts(error_codes.ASSET_NOT_SUPPORTED):
        asset_registry.getAssetRange(TokenAddresses.DAI)


def test_set_asset_range(admin, asset_registry):
    asset_registry.setAssetAddress("DAI", TokenAddresses.DAI)
    price_range = Range(scale("0.95"), scale("1.02"))
    asset_registry.setAssetRange(TokenAddresses.DAI, price_range, {"from": admin})
    assert asset_registry.getAssetRange(TokenAddresses.DAI) == price_range
