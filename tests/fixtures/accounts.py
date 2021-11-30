import pytest


@pytest.fixture(scope="session")
def alice(accounts):
    return accounts[1]


@pytest.fixture(scope="session")
def bob(accounts):
    return accounts[2]


@pytest.fixture(scope="session")
def charlie(accounts):
    return accounts[3]


@pytest.fixture(scope="session")
def admin(accounts):
    return accounts[4]


@pytest.fixture(scope="session")
def gov(accounts):
    return accounts[5]
