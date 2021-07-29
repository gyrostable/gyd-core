import pytest
from brownie import accounts


@pytest.fixture()
def lp_token_exchanger_registry(admin, LPTokenExchangerRegistry):
    return admin.deploy(LPTokenExchangerRegistry)


@pytest.fixture()
def mock_vault_router(admin, MockVaultRouter):
    return admin.deploy(MockVaultRouter)


@pytest.fixture()
def mock_lp_token_exchanger(admin, MockLPTokenExchanger):
    return admin.deploy(MockLPTokenExchanger)


@pytest.fixture(scope="module")
def dai(Token):
    yield Token.deploy("Dai Token", "DAI", 18, 1e20, {"from": accounts[0]})


@pytest.fixture(scope="module")
def usdc(Token):
    yield Token.deploy("USDC Token", "USDC", 6, 1e20, {"from": accounts[0]})


@pytest.fixture(scope="module")
def usdt(Token):
    yield Token.deploy("Tether", "USDT", 6, 1e20, {"from": accounts[0]})


@pytest.fixture(scope="module")
def lp_token(Token):
    yield Token.deploy("LP Token", "LPT", 18, 1e20, {"from": accounts[0]})


# @pytest.fixture
# def distribute_dai(dai):
#     for i in range(1, 10):
#         dai.transfer(accounts[i], 100, {"from": accounts[0]})


# @pytest.fixture
# def distribute_usdt(usdt):
#     for i in range(1, 10):
#         usdt.transfer(accounts[i], 100, {"from": accounts[0]})


# @pytest.fixture
# def distribute_usdc(usdc):
#     for i in range(1, 10):
#         usdc.transfer(accounts[i], 100, {"from": accounts[0]})


@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass
