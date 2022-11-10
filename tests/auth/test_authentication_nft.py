from brownie.test.managers.runner import RevertContextManager as reverts

from tests.support import error_codes


def test_mint(authentication_nft, admin, alice):
    with reverts(error_codes.NOT_AUTHORIZED):
        authentication_nft.mint(alice, {"from": alice})
    authentication_nft.mint(alice, {"from": admin})
    assert authentication_nft.ownerOf(0) == alice
    authentication_nft.mint(alice, {"from": admin})
    assert authentication_nft.ownerOf(1) == alice


def test_burn(authentication_nft, admin, alice, bob):
    authentication_nft.mint(alice, {"from": admin})
    with reverts(error_codes.NOT_AUTHORIZED):
        authentication_nft.burn(0, {"from": alice})
    with reverts(error_codes.NOT_AUTHORIZED):
        authentication_nft.burn(0, {"from": bob})

    authentication_nft.burn(0, {"from": admin})

    assert authentication_nft.totalSupply() == 0
    authentication_nft.mint(alice, {"from": admin})
    assert authentication_nft.ownerOf(1) == alice
