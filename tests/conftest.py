import pytest

from brownie.network import gas_price, priority_fee
from brownie._config import CONFIG

pytest_plugins = [
    "tests.fixtures.deployments",
    "tests.fixtures.accounts",
]


@pytest.fixture(scope="module")
def admin(accounts):
    return accounts[0]


@pytest.fixture(autouse=True)
def isolation_setup(fn_isolation):
    pass


@pytest.fixture(scope="session")
def is_forked():
    return "fork" in CONFIG.active_network["id"]


@pytest.fixture(scope="session", autouse=True)
def set_gas_price(is_forked):
    if is_forked:
        priority_fee("2 gwei")
    else:
        gas_price("2 gwei")


@pytest.fixture(scope="module")
def gyro_lp_price_testing(admin, TestingLPSharePricing):
    return admin.deploy(TestingLPSharePricing)
