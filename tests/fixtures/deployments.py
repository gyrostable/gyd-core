from collections import namedtuple
from unittest.mock import Mock

import pytest
from brownie import accounts
from tests.fixtures.mainnet_contracts import (
    ChainlinkFeeds,
    TokenAddresses,
    UniswapPools,
)
from tests.support import constants
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
def mock_price_oracle(admin, MockPriceOracle):
    return admin.deploy(MockPriceOracle)


@pytest.fixture(scope="module")
def asset_pricer(admin, AssetPricer, mock_price_oracle):
    return admin.deploy(AssetPricer, mock_price_oracle)


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
def motherboard(
    admin,
    Motherboard,
    gyd_token,
    fee_bank,
    gyro_config,
    lp_token_exchanger_registry,
    mock_pamm,
    reserve,
    mock_price_oracle,
):
    args = MotherboardArgs(
        gydToken=gyd_token,
        exchangerRegistry=lp_token_exchanger_registry,
        pamm=mock_pamm,
        gyroConfig=gyro_config,
        feeBank=fee_bank,
        reserve=reserve,
        priceOracle=mock_price_oracle,
    )
    return admin.deploy(Motherboard, args)


@pytest.fixture(scope="module")
def pamm(TestingPAMMV1):
    return TestingPAMMV1.deploy(
        (constants.ALPHA_MIN_REL, constants.XU_MAX_REL, constants.THETA_FLOOR),
        {"from": accounts[0]},
    )


@pytest.fixture(scope="module")
def balancer_safety_checks(
    admin,
    BalancerSafetyChecks,
    asset_registry,
    mock_price_oracle,
    asset_pricer,
    mock_balancer_vault,
):
    return admin.deploy(
        BalancerSafetyChecks,
        mock_balancer_vault,
        asset_registry,
        mock_price_oracle,
        asset_pricer,
        constants.MAX_BALANCER_ACTIVITY_LAG,
        constants.STABLECOIN_MAX_DEVIATION,
        constants.MAX_POOL_WEIGHT_DEVIATION,
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
