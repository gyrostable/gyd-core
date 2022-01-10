from collections import namedtuple

import pytest
from brownie import accounts
from tests.support import constants

MotherboardArgs = namedtuple(
    "MotherboardArgs",
    [
        "gydToken",
        "exchangerRegistry",
        "pamm",
        "gyroConfig",
        "feeBank",
        "reserve",
        "priceOracle",
    ],
)


@pytest.fixture(scope="module")
def lp_token_exchanger_registry(admin, LPTokenExchangerRegistry):
    return admin.deploy(LPTokenExchangerRegistry)


@pytest.fixture(scope="module")
def gyd_token(admin, ERC20):
    return admin.deploy(ERC20, "GYD Token", "GYD")


@pytest.fixture(scope="module")
def fee_bank(admin, FeeBank):
    return admin.deploy(FeeBank)


@pytest.fixture(scope="module")
def reserve(admin, Reserve):
    return admin.deploy(Reserve)


@pytest.fixture(scope="module")
def mock_vault_router(admin, MockVaultRouter):
    return admin.deploy(MockVaultRouter)


@pytest.fixture(scope="module")
def mock_lp_token_exchanger(admin, MockLPTokenExchanger):
    return admin.deploy(MockLPTokenExchanger)


@pytest.fixture(scope="module")
def bal_exchanger(admin, BalancerExchanger):
    return admin.deploy(BalancerExchanger)


@pytest.fixture(scope="module")
def bal_pool_registry(admin, BalancerPoolRegistry):
    print("bal pool registry")
    return admin.deploy(BalancerPoolRegistry)


@pytest.fixture(scope="module")
def gyro_config(admin, GyroConfig):
    return admin.deploy(GyroConfig)


@pytest.fixture(scope="module")
def dai(Token):
    token = Token.deploy("Dai Token", "DAI", 18, 1e20, {"from": accounts[0]})
    for i in range(1, 10):
        token.transfer(accounts[i], 100, {"from": accounts[0]})
    yield token


@pytest.fixture(scope="module")
def usdc(Token):
    token = Token.deploy("USDC Token", "USDC", 6, 1e20, {"from": accounts[0]})
    for i in range(1, 10):
        token.transfer(accounts[i], 100, {"from": accounts[0]})
    yield token


@pytest.fixture(scope="module")
def usdt(Token):
    token = Token.deploy("Tether", "USDT", 6, 1e20, {"from": accounts[0]})
    for i in range(1, 10):
        token.transfer(accounts[i], 100, {"from": accounts[0]})
    yield token


@pytest.fixture(scope="module")
def lp_token(Token):
    yield Token.deploy("LP Token", "LPT", 18, 1e20, {"from": accounts[0]})


@pytest.fixture(scope="module")
def mock_pamm(admin, MockPAMM):
    return admin.deploy(MockPAMM)


@pytest.fixture(scope="module")
def price_oracle(admin, MockPriceOracle):
    return admin.deploy(MockPriceOracle)


@pytest.fixture(scope="module")
def motherboard(
    admin,
    Motherboard,
    gyd_token,
    fee_bank,
    gyro_config,
    lp_token_exchanger_registry,
    mock_pamm,
    reserve,
    price_oracle,
):
    args = MotherboardArgs(
        gydToken=gyd_token,
        exchangerRegistry=lp_token_exchanger_registry,
        pamm=mock_pamm,
        gyroConfig=gyro_config,
        feeBank=fee_bank,
        reserve=reserve,
        priceOracle=price_oracle,
    )
    return admin.deploy(Motherboard, args)


@pytest.fixture(scope="module")
def pamm(TestingPAMMV1):
    return TestingPAMMV1.deploy(
        (constants.ALPHA_MIN_REL, constants.XU_MAX_REL, constants.THETA_FLOOR),
        {"from": accounts[0]},
    )
