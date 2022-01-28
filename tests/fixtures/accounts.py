import pytest


@pytest.fixture(scope="session")
def deployer(accounts):
    return accounts[0]


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


@pytest.fixture(scope="session")
def price_signer(accounts):
    return accounts.add(
        "0xb0057716d5917badaf911b193b12b910811c1497b5bada8d7711f758981c3773"
    )
