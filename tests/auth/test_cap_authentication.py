from brownie.test.managers.runner import RevertContextManager as reverts

from tests.support import error_codes


def test_authenticate(cap_authentication, admin, alice):
    with reverts(error_codes.NOT_AUTHORIZED):
        cap_authentication.authenticate(alice, {"from": alice})
    cap_authentication.authenticate(alice, {"from": admin})
    assert cap_authentication.isAuthenticated(alice)


def test_deauthenticate(cap_authentication, admin, alice, bob):
    cap_authentication.authenticate(alice, {"from": admin})
    with reverts(error_codes.NOT_AUTHORIZED):
        cap_authentication.deauthenticate(alice, {"from": alice})
    with reverts(error_codes.NOT_AUTHORIZED):
        cap_authentication.deauthenticate(alice, {"from": bob})

    cap_authentication.deauthenticate(alice, {"from": admin})

    assert cap_authentication.listAuthenticatedAccounts() == [admin]
    cap_authentication.authenticate(alice, {"from": admin})
    assert cap_authentication.listAuthenticatedAccounts() == [admin, alice]
