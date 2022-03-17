import pytest

from brownie.network import gas_price, priority_fee
from brownie._config import CONFIG

pytest_plugins = [
    "tests.fixtures.coins",
    "tests.fixtures.deployments",
    "tests.fixtures.mainnet_initialization",
    "tests.fixtures.accounts",
]


def pytest_addoption(parser):
    parser.addoption("--underlying", help="only run tests for given underlying")


def pytest_generate_tests(metafunc):
    if "underlying" in metafunc.fixturenames:
        underlying = metafunc.config.getoption("underlying")
        if underlying:
            underlying = underlying.split(",")
        else:
            underlying = ["dai", "usdc", "usdt"]
        metafunc.parametrize("underlying", underlying, indirect=True, scope="module")


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
