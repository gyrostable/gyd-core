import pytest

from brownie.network import gas_price

pytest_plugins = [
    "tests.fixtures.deployments",
    "tests.fixtures.accounts",
]


@pytest.fixture(autouse=True)
def isolation_setup(fn_isolation):
    pass


@pytest.fixture(scope="session", autouse=True)
def set_gas_price():
    return gas_price("2 gwei")
