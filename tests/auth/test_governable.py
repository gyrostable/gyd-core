import pytest
from brownie import ZERO_ADDRESS
from brownie.test.managers.runner import RevertContextManager as reverts
from tests.support import error_codes


@pytest.fixture(scope="module")
def governable(Governable, admin):
    return admin.deploy(Governable, admin)


def test_views(governable, admin):
    assert governable.governor() == admin
    assert governable.pendingGovernor() == ZERO_ADDRESS


def test_change_governor_unauthorized(governable, alice):
    with reverts(error_codes.NOT_AUTHORIZED):
        governable.changeGovernor(alice, {"from": alice})


def test_change_governor(governable, admin, alice):
    tx = governable.changeGovernor(alice, {"from": admin})
    assert governable.governor() == admin
    assert governable.pendingGovernor() == alice
    assert tx.events["GovernorChangeRequested"]["newGovernor"] == alice


def test_accept_governance_unauthorized(governable, admin, alice, bob):
    with reverts(error_codes.NOT_AUTHORIZED):
        governable.acceptGovernance({"from": alice})
    governable.changeGovernor(alice, {"from": admin})
    with reverts(error_codes.NOT_AUTHORIZED):
        governable.acceptGovernance({"from": bob})


def test_accept_governance(governable, admin, alice):
    governable.changeGovernor(alice, {"from": admin})
    tx = governable.acceptGovernance({"from": alice})
    assert governable.governor() == alice
    assert governable.pendingGovernor() == ZERO_ADDRESS
    assert tx.events["GovernorChanged"]["oldGovernor"] == admin
    assert tx.events["GovernorChanged"]["newGovernor"] == alice
