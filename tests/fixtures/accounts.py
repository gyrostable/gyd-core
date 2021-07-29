import pytest


@pytest.fixture(scope="session", autouse=True)
def alice(accounts):
    return accounts[1]


@pytest.fixture(scope="session", autouse=True)
def bob(accounts):
    return accounts[2]


@pytest.fixture(scope="session", autouse=True)
def charlie(accounts):
    return accounts[3]


@pytest.fixture(scope="session", autouse=True)
def admin(accounts):
    return accounts[4]


@pytest.fixture(scope="session", autouse=True)
def gov(accounts):
    return accounts[5]
