from brownie.test.managers.runner import RevertContextManager as reverts

from tests.support import error_codes


def test_owners(multi_ownable, admin):
    assert multi_ownable.owners() == [admin]


def test_add_owner(multi_ownable, admin, alice):
    multi_ownable.addOwner(alice, {"from": admin})
    assert multi_ownable.owners() == [admin, alice]
    with reverts(error_codes.INVALID_ARGUMENT):
        multi_ownable.addOwner(alice, {"from": admin})


def test_remove_owner(multi_ownable, admin, alice):
    multi_ownable.addOwner(alice, {"from": admin})
    multi_ownable.removeOwner(alice, {"from": admin})
    assert multi_ownable.owners() == [admin]
    with reverts(error_codes.INVALID_ARGUMENT):
        multi_ownable.removeOwner(alice, {"from": admin})
    with reverts(error_codes.NOT_AUTHORIZED):
        multi_ownable.removeOwner(admin, {"from": admin})
