import pytest
from brownie import accounts
from tests.support import config_keys, constants
from tests.support.types import PammParams
from tests.support.utils import scale


@pytest.fixture(scope="module")
def vault_registry(admin, VaultRegistry, gyro_config):
    vault_registry = admin.deploy(VaultRegistry, gyro_config)
    gyro_config.setAddress(
        config_keys.VAULT_REGISTRY_ADDRESS, vault_registry, {"from": admin}
    )
    return vault_registry


@pytest.fixture(scope="module")
def balancer_cpmm_price_oracle(BalancerCPMMPriceOracle, admin):
    return admin.deploy(BalancerCPMMPriceOracle)


@pytest.fixture(scope="module")
def reserve_manager(admin, ReserveManager, gyro_config, request, vault_registry):
    dependencies = ["reserve", "mock_price_oracle"]
    for dep in dependencies:
        request.getfixturevalue(dep)
    reserve_manager = admin.deploy(ReserveManager, gyro_config)
    gyro_config.setAddress(
        config_keys.RESERVE_MANAGER_ADDRESS, reserve_manager, {"from": admin}
    )
    vault_registry.setReserveManagerAddress(reserve_manager, {"from": admin})
    return reserve_manager


@pytest.fixture(scope="module")
def static_percentage_fee_handler(StaticPercentageFeeHandler, admin, gyro_config):
    fee_handler = admin.deploy(StaticPercentageFeeHandler)
    gyro_config.setAddress(
        config_keys.FEE_HANDLER_ADDRESS, fee_handler, {"from": admin}
    )
    return fee_handler


@pytest.fixture(scope="module")
def gyd_token(admin, GydToken, gyro_config):
    gyd_token = admin.deploy(GydToken, gyro_config, "GYD Token", "GYD")
    gyro_config.setAddress(config_keys.GYD_TOKEN_ADDRESS, gyd_token, {"from": admin})
    return gyd_token


@pytest.fixture(scope="module")
def fee_bank(admin, FeeBank, gyro_config):
    fee_bank = admin.deploy(FeeBank)
    gyro_config.setAddress(config_keys.FEE_BANK_ADDRESS, fee_bank, {"from": admin})
    return fee_bank


@pytest.fixture(scope="module")
def reserve(admin, Reserve, gyro_config):
    reserve = admin.deploy(Reserve)
    gyro_config.setAddress(config_keys.RESERVE_ADDRESS, reserve, {"from": admin})
    return reserve


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
def gyro_config(admin, GyroConfig):
    config = admin.deploy(GyroConfig)
    config.initialize(admin)
    return config


@pytest.fixture(scope="module")
def lp_token(Token):
    yield Token.deploy("LP Token", "LPT", 18, scale(10_000), {"from": accounts[0]})


@pytest.fixture(scope="module")
def mock_pamm(admin, MockPAMM, gyro_config):
    pamm = admin.deploy(MockPAMM)
    gyro_config.setAddress(config_keys.PAMM_ADDRESS, pamm, {"from": admin})
    return pamm


@pytest.fixture(scope="module")
def mock_price_oracle(admin, MockPriceOracle, gyro_config):
    mock_price_oracle = admin.deploy(MockPriceOracle)
    gyro_config.setAddress(
        config_keys.ROOT_PRICE_ORACLE_ADDRESS, mock_price_oracle, {"from": admin}
    )
    return mock_price_oracle


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


@pytest.fixture(scope="module")
def chainlink_price_oracle(ChainlinkPriceOracle, admin):
    return admin.deploy(ChainlinkPriceOracle)


@pytest.fixture(scope="module")
def crash_protected_chainlink_oracle(CrashProtectedChainlinkPriceOracle, admin):
    return admin.deploy(CrashProtectedChainlinkPriceOracle)


@pytest.fixture(scope="module")
def local_checked_price_oracle(admin, mock_price_oracle, CheckedPriceOracle):
    return admin.deploy(CheckedPriceOracle, mock_price_oracle, mock_price_oracle)


@pytest.fixture(scope="module")
def testing_checked_price_oracle(admin, mock_price_oracle, TestingCheckedPriceOracle):
    return admin.deploy(TestingCheckedPriceOracle, mock_price_oracle, mock_price_oracle)


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
def root_safety_check(admin, RootSafetyCheck, gyro_config):
    safety_check = admin.deploy(RootSafetyCheck, gyro_config)
    gyro_config.setAddress(
        config_keys.ROOT_SAFETY_CHECK_ADDRESS, safety_check, {"from": admin}
    )
    return safety_check


@pytest.fixture(scope="module")
def motherboard(admin, Motherboard, gyro_config, reserve, request):
    extra_dependencies = [
        "fee_bank",
        "mock_pamm",
        "mock_price_oracle",
        "reserve_manager",
        "root_safety_check",
        "static_percentage_fee_handler",
        "gyd_token",
    ]
    for dep in extra_dependencies:
        request.getfixturevalue(dep)
    motherboard = admin.deploy(Motherboard, gyro_config)
    reserve.addManager(motherboard, {"from": admin})
    gyro_config.setAddress(
        config_keys.MOTHERBOARD_ADDRESS, motherboard, {"from": admin}
    )
    return motherboard


@pytest.fixture(scope="module")
def pamm(TestingPAMMV1, gyro_config):
    return TestingPAMMV1.deploy(
        gyro_config,
        PammParams(
            int(constants.ALPHA_MIN_REL),
            int(constants.XU_MAX_REL),
            int(constants.THETA_FLOOR),
            int(constants.OUTFLOW_MEMORY),
        ),
        {"from": accounts[0]},
    )


@pytest.fixture(scope="module")
def reserve_safety_manager(admin, TestingReserveSafetyManager, asset_registry):
    return admin.deploy(
        TestingReserveSafetyManager,
        constants.MAX_ALLOWED_VAULT_DEVIATION,
        constants.STABLECOIN_MAX_DEVIATION,
        constants.MIN_TOKEN_PRICE,
        asset_registry,
    )


@pytest.fixture(scope="module")
def set_data_for_mock_bal_vault(
    mock_balancer_vault,
    mock_balancer_pool,
    mock_balancer_pool_two,
    dai,
    usdc,
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


# NOTE: this is a vault that contains only USDC as underlying
# this is for testing purposes only
@pytest.fixture(scope="module")
def usdc_vault(admin, BaseVault, usdc):
    return admin.deploy(BaseVault, usdc, "USDC Vault", "gUSDC")


@pytest.fixture(scope="module")
def mock_vaults(admin, MockGyroVault, dai):
    return [admin.deploy(MockGyroVault, dai) for _ in range(constants.RESERVE_VAULTS)]


@pytest.fixture(scope="module")
def batch_vault_price_oracle(admin, TestingBatchVaultPriceOracle, mock_price_oracle):
    return admin.deploy(TestingBatchVaultPriceOracle, mock_price_oracle)


# NOTE: this is a vault that contains only DAI as underlying
# this is for testing purposes only
@pytest.fixture(scope="module")
def dai_vault(admin, BaseVault, dai):
    return admin.deploy(BaseVault, dai, "DAI Vault", "gDAI")


@pytest.fixture(scope="module")
def balancer_vault(interface):
    return interface.IVault(constants.BALANCER_VAULT_ADDRESS)


@pytest.fixture(scope="module")
def vault_safety_mode(admin, TestingVaultSafetyMode, request, gyro_config):
    request.getfixturevalue("motherboard")
    return admin.deploy(
        TestingVaultSafetyMode,
        constants.SAFETY_BLOCKS_AUTOMATIC,
        constants.SAFETY_BLOCKS_GUARDIAN,
        gyro_config,
    )


@pytest.fixture(scope="module")
def testing_fixed_point(admin, TestingFixedPoint):
    return admin.deploy(TestingFixedPoint)


@pytest.fixture(scope="module")
def multi_ownable(admin, MultiOwnable):
    return admin.deploy(MultiOwnable)


@pytest.fixture(scope="module")
def cap_authentication(admin, CapAuthentication):
    return admin.deploy(CapAuthentication)
