import brownie
from brownie.test.managers.runner import RevertContextManager as reverts
from tests.support import error_codes
from tests.support.constants import DAI_ADDRESS, WBTC_ADDRESS
from tests.support.utils import format_to_bytes


def test_set_asset_address(asset_registry):
    assert len(asset_registry.getRegisteredAssetNames()) == 0
    assert len(asset_registry.getRegisteredAssetAddresses()) == 0
    assert len(asset_registry.getStableAssets()) == 0
    assert not asset_registry.isAssetNameRegistered("BTC")
    asset_registry.setAssetAddress("BTC", WBTC_ADDRESS)
    assert asset_registry.isAssetNameRegistered("BTC")
    assert asset_registry.isAssetAddressRegistered(WBTC_ADDRESS)
    assert not asset_registry.isAssetStable(WBTC_ADDRESS)
    assert asset_registry.getRegisteredAssetNames() == (
        format_to_bytes("BTC", 32, output_hex=True),
    )
    assert asset_registry.getRegisteredAssetAddresses() == (WBTC_ADDRESS,)
    assert asset_registry.getAssetAddress("BTC") == WBTC_ADDRESS
    assert len(asset_registry.getStableAssets()) == 0


def test_add_stable_non_existent_asset(asset_registry):
    with reverts(error_codes.ASSET_NOT_SUPPORTED):
        asset_registry.addStableAsset(WBTC_ADDRESS)


def test_add_stable_asset(asset_registry):
    assert not asset_registry.isAssetStable(DAI_ADDRESS)
    asset_registry.setAssetAddress("DAI", DAI_ADDRESS)
    assert not asset_registry.isAssetStable(DAI_ADDRESS)
    tx = asset_registry.addStableAsset(DAI_ADDRESS)
    assert tx.events["StableAssetAdded"]["asset"] == DAI_ADDRESS
    assert asset_registry.isAssetStable(DAI_ADDRESS)
    assert asset_registry.getStableAssets() == (DAI_ADDRESS,)


def test_remove_stable_asset(asset_registry):
    asset_registry.setAssetAddress("DAI", DAI_ADDRESS)
    asset_registry.addStableAsset(DAI_ADDRESS)
    assert asset_registry.isAssetStable(DAI_ADDRESS)
    tx = asset_registry.removeStableAsset(DAI_ADDRESS)
    assert tx.events["StableAssetRemoved"]["asset"] == DAI_ADDRESS
    assert not asset_registry.isAssetStable(DAI_ADDRESS)
    assert len(asset_registry.getStableAssets()) == 0


def test_set_asset_address_fails_with_zero_address(asset_registry):
    with reverts(error_codes.INVALID_ARGUMENT):
        asset_registry.setAssetAddress("BTC", brownie.ZERO_ADDRESS)


def test_set_asset_address_fails_without_authorization(asset_registry, alice):
    with reverts(error_codes.NOT_AUTHORIZED):
        asset_registry.setAssetAddress("BTC", WBTC_ADDRESS, {"from": alice})


def test_add_stable_asset_fails_without_authorization(asset_registry, admin, alice):
    asset_registry.setAssetAddress("DAI", DAI_ADDRESS, {"from": admin})
    with reverts(error_codes.NOT_AUTHORIZED):
        asset_registry.addStableAsset(DAI_ADDRESS, {"from": alice})


def test_remove_stable_asset_fails_without_authorization(asset_registry, admin, alice):
    asset_registry.setAssetAddress("DAI", DAI_ADDRESS, {"from": admin})
    asset_registry.addStableAsset(DAI_ADDRESS, {"from": admin})
    with reverts(error_codes.NOT_AUTHORIZED):
        asset_registry.removeStableAsset(DAI_ADDRESS, {"from": alice})


def test_remove_asset(asset_registry):
    asset_registry.setAssetAddress("DAI", DAI_ADDRESS)
    asset_registry.addStableAsset(DAI_ADDRESS)
    assert asset_registry.isAssetNameRegistered("DAI")
    assert asset_registry.isAssetStable(DAI_ADDRESS)
    asset_registry.removeAsset("DAI")
    assert len(asset_registry.getRegisteredAssetNames()) == 0
    assert len(asset_registry.getRegisteredAssetAddresses()) == 0
    assert not asset_registry.isAssetNameRegistered("DAI")
    assert not asset_registry.isAssetAddressRegistered(DAI_ADDRESS)
    assert not asset_registry.isAssetStable(DAI_ADDRESS)
