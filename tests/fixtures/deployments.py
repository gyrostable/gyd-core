from collections import namedtuple
from unittest.mock import Mock

import pytest
from brownie import accounts
from tests.fixtures.mainnet_contracts import (
    ChainlinkFeeds,
    TokenAddresses,
    UniswapPools,
)
from tests.support import config_keys, constants
from tests.support.utils import scale

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
def lp_token_exchanger_registry(admin, LPTokenExchangerRegistry, gyro_config):
    exchanger_registry = admin.deploy(LPTokenExchangerRegistry)
    gyro_config.setAddress(config_keys.EXCHANGER_REGISTRY_ADDRESS, exchanger_registry)
    return exchanger_registry


@pytest.fixture(scope="module")
def gyd_token(admin, ERC20, gyro_config):
    gyd_token = admin.deploy(ERC20, "GYD Token", "GYD")
    gyro_config.setAddress(config_keys.GYD_TOKEN_ADDRESS, gyd_token)
    return gyd_token


@pytest.fixture(scope="module")
def fee_bank(admin, FeeBank, gyro_config):
    fee_bank = admin.deploy(FeeBank)
    gyro_config.setAddress(config_keys.FEE_BANK_ADDRESS, fee_bank)
    return fee_bank


@pytest.fixture(scope="module")
def reserve(admin, Reserve, gyro_config):
    reserve = admin.deploy(Reserve)
    gyro_config.setAddress(config_keys.RESERVE_ADDRESS, reserve)
    return reserve


@pytest.fixture(scope="module")
def mock_vault_router(admin, MockVaultRouter):
    return admin.deploy(MockVaultRouter)


@pytest.fixture(scope="module")
def mock_balancer_pool(admin, MockBalancerPool):
    return admin.deploy(MockBalancerPool, constants.BALANCER_POOL_ID)


@pytest.fixture(scope="module")
def mock_balancer_pool_two(admin, MockBalancerPool):
    return admin.deploy(MockBalancerPool, constants.BALANCER_POOL_ID_2)


@pytest.fixture(scope="module")
def mock_balancer_vault(admin, MockBalVault):
    return admin.deploy(MockBalVault)


@pytest.fixture(scope="module")
def mock_lp_token_exchanger(admin, MockLPTokenExchanger):
    return admin.deploy(MockLPTokenExchanger)


@pytest.fixture(scope="module")
def bal_exchanger(admin, BalancerExchanger):
    return admin.deploy(BalancerExchanger)


@pytest.fixture(scope="module")
def bal_pool_registry(admin, BalancerPoolRegistry):
    return admin.deploy(BalancerPoolRegistry)


@pytest.fixture(scope="module")
def gyro_config(admin, GyroConfig):
    return admin.deploy(GyroConfig)


@pytest.fixture(scope="module")
def dai(Token):
    token = Token.deploy("Dai Token", "DAI", 18, scale(10_000), {"from": accounts[0]})
    for i in range(1, 10):
        token.transfer(accounts[i], scale(100), {"from": accounts[0]})
    yield token


@pytest.fixture(scope="module")
def sdt(Token):
    token = Token.deploy("SDT Token", "SDT", 18, scale(10_000), {"from": accounts[0]})
    for i in range(1, 10):
        token.transfer(accounts[i], scale(100), {"from": accounts[0]})
    yield token


@pytest.fixture(scope="module")
def abc(Token):
    token = Token.deploy("ABC Token", "ABC", 18, scale(10_000), {"from": accounts[0]})
    for i in range(1, 10):
        token.transfer(accounts[i], scale(100), {"from": accounts[0]})
    yield token


@pytest.fixture(scope="module")
def usdc(Token):
    token = Token.deploy(
        "USDC Token", "USDC", 6, scale(10_000, 6), {"from": accounts[0]}
    )
    for i in range(1, 10):
        token.transfer(accounts[i], scale(100, 6), {"from": accounts[0]})
    yield token


@pytest.fixture(scope="module")
def usdt(Token):
    token = Token.deploy("Tether", "USDT", 6, scale(10_000, 6), {"from": accounts[0]})
    for i in range(1, 10):
        token.transfer(accounts[i], scale(100, 6), {"from": accounts[0]})
    yield token


@pytest.fixture(scope="module")
def lp_token(Token):
    yield Token.deploy("LP Token", "LPT", 18, scale(10_000), {"from": accounts[0]})


@pytest.fixture(scope="module")
def mock_pamm(admin, MockPAMM, gyro_config):
    pamm = admin.deploy(MockPAMM)
    gyro_config.setAddress(config_keys.PAMM_ADDRESS, pamm)
    return pamm


@pytest.fixture(scope="module")
def mock_price_oracle(admin, MockPriceOracle, gyro_config):
    mock_price_oracle = admin.deploy(MockPriceOracle)
    gyro_config.setAddress(config_keys.ROOT_PRICE_ORACLE_ADDRESS, mock_price_oracle)
    return mock_price_oracle


@pytest.fixture(scope="module")
def asset_pricer(admin, AssetPricer, gyro_config):
    return admin.deploy(AssetPricer, gyro_config)


@pytest.fixture(scope="module")
def asset_registry(admin, AssetRegistry):
    return admin.deploy(AssetRegistry)


@pytest.fixture(scope="module")
def coinbase_price_oracle(admin, TestingTrustedSignerPriceOracle, asset_registry):
    return admin.deploy(
        TestingTrustedSignerPriceOracle,
        asset_registry,
        constants.COINBASE_SIGNING_ADDRESS,
    )


@pytest.fixture(scope="module")
def local_signer_price_oracle(
    admin, TestingTrustedSignerPriceOracle, asset_registry, price_signer
):
    return admin.deploy(TestingTrustedSignerPriceOracle, asset_registry, price_signer)


@pytest.fixture(scope="module")
def uniswap_v3_twap_oracle(admin, UniswapV3TwapOracle):
    return admin.deploy(UniswapV3TwapOracle)


@pytest.fixture
def add_common_uniswap_pools(admin, uniswap_v3_twap_oracle):
    pools = [UniswapPools.ETH_CRV, UniswapPools.USDC_ETH, UniswapPools.WBTC_USDC]
    for pool in pools:
        uniswap_v3_twap_oracle.registerPool(pool, {"from": admin})


@pytest.fixture(scope="module")
def chainlink_price_oracle(ChainlinkPriceOracle, admin):
    return admin.deploy(ChainlinkPriceOracle)


@pytest.fixture
def set_common_chainlink_feeds(admin, chainlink_price_oracle):
    feeds = [
        (TokenAddresses.ETH, ChainlinkFeeds.ETH_USD_FEED),
        (TokenAddresses.WETH, ChainlinkFeeds.ETH_USD_FEED),
        (TokenAddresses.DAI, ChainlinkFeeds.DAI_USD_FEED),
        (TokenAddresses.WBTC, ChainlinkFeeds.WBTC_USD_FEED),
        (TokenAddresses.CRV, ChainlinkFeeds.CRV_USD_FEED),
        (TokenAddresses.USDC, ChainlinkFeeds.USDC_USD_FEED),
    ]
    for asset, feed in feeds:
        chainlink_price_oracle.setFeed(asset, feed, {"from": admin})


@pytest.fixture(scope="module")
def local_checked_price_oracle(admin, mock_price_oracle, CheckedPriceOracle):
    return admin.deploy(CheckedPriceOracle, mock_price_oracle, mock_price_oracle)


@pytest.fixture(scope="module")
def mainnet_checked_price_oracle(
    admin, chainlink_price_oracle, uniswap_v3_twap_oracle, CheckedPriceOracle
):

    mainnet_checked_price_oracle = admin.deploy(
        CheckedPriceOracle, chainlink_price_oracle, uniswap_v3_twap_oracle
    )
    # set the relative max epsilon slightly larger to avoid tests randomly failing
    mainnet_checked_price_oracle.setRelativeMaxEpsilon(scale("0.03"))
    return mainnet_checked_price_oracle


@pytest.fixture(scope="module")
def motherboard(admin, Motherboard, gyro_config, reserve, request):
    dependencies = [
        "gyd_token",
        "fee_bank",
        "lp_token_exchanger_registry",
        "mock_pamm",
        "mock_price_oracle",
    ]
    for dep in dependencies:
        request.getfixturevalue(dep)
    motherboard = admin.deploy(Motherboard, gyro_config)
    reserve.addManager(motherboard, {"from": admin})
    return motherboard


@pytest.fixture(scope="module")
def pamm(TestingPAMMV1):
    return TestingPAMMV1.deploy(
        (constants.ALPHA_MIN_REL, constants.XU_MAX_REL, constants.THETA_FLOOR),
        {"from": accounts[0]},
    )


@pytest.fixture(scope="module")
def reserve_safety_manager(
    admin,
    TestingReserveSafetyManager,
    mock_balancer_vault,
    mock_price_oracle,
    asset_registry,
):
    return admin.deploy(
        TestingReserveSafetyManager,
        constants.MAX_ALLOWED_VAULT_DEVIATION,
        constants.STABLECOIN_MAX_DEVIATION,
        constants.MIN_TOKEN_PRICE,
        mock_balancer_vault,
        mock_price_oracle,
        asset_registry,
    )


@pytest.fixture(scope="module")
def set_data_for_mock_bal_vault(
    mock_balancer_vault, mock_balancer_pool, mock_balancer_pool_two, dai, usdc
):
    mock_balancer_vault.setCash(100000000000000000000000000)
    mock_balancer_vault.setPoolTokens(
        constants.BALANCER_POOL_ID, [dai, usdc], [2e20, 2e20]
    )
    mock_balancer_vault.storePoolAddress(constants.BALANCER_POOL_ID, mock_balancer_pool)
    mock_balancer_vault.storePoolAddress(
        constants.BALANCER_POOL_ID_2, mock_balancer_pool_two
    )


@pytest.fixture(scope="module")
def underlying(request):
    return request.getfixturevalue(request.param)


@pytest.fixture(scope="module")
def decimals(underlying, interface):
    return interface.ERC20(underlying).decimals()


@pytest.fixture(scope="module")
def vault(admin, BaseVault, underlying):
    return admin.deploy(BaseVault, underlying, "Base Vault Token", "BVT")
