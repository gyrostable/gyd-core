import pytest

pytest_plugins = [
    "tests.fixtures.deployments",
    "tests.fixtures.accounts",
]


@pytest.fixture(autouse=True)
def isolation_setup(fn_isolation):
    pass
