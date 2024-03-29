import pytest
from brownie import accounts
from .mainnet_contracts import TokenAddresses
from tests.support import config_keys, constants
from tests.support.types import (
    PammParams,
    PersistedVaultMetadata,
    VaultConfiguration,
)
from tests.support.utils import scale

GYD_RECOVERY_WITHDRAWAL_WAIT_DURATION = 30 * constants.SECONDS_PER_DAY
GYD_RECOVERY_MAX_WITHDRAWAL_WAIT_DURATION = 90 * constants.SECONDS_PER_DAY
GYD_RECOVERY_MAX_TRIGGER_CR = scale("1.0")
GYD_RECOVERY_TRIGGER_CR = scale("0.8")
GYD_RECOVERY_TARGET_CR = scale("1.0")

STEWARDSHIP_INC_MIN_CR = scale("1.05")
STEWARDSHIP_INC_DURATION = 365 * 24 * 60 * 60
STEWARDSHIP_INC_MAX_VIOLATIONS = 1


@pytest.fixture(scope="module")
def vault_registry(admin, VaultRegistry, gyro_config, deploy_with_proxy):
    vault_registry = deploy_with_proxy(
        VaultRegistry, lambda c: c.initialize.encode_input(admin), gyro_config
    )
    gyro_config.setAddress(
        config_keys.VAULT_REGISTRY_ADDRESS, vault_registry, {"from": admin}
    )
    return vault_registry


@pytest.fixture(scope="module")
def uniswap_spot_price_oracle(SpotRelativePriceOracle, admin):
    return admin.deploy(SpotRelativePriceOracle, constants.UNISWAP_ROUTER)


@pytest.fixture(scope="module")
def balancer_cpmm_price_oracle(BalancerCPMMPriceOracle, admin):
    return admin.deploy(BalancerCPMMPriceOracle)


@pytest.fixture(scope="module")
def reserve_manager(admin, ReserveManager, gyro_config, request):
    dependencies = [
        "reserve",
        "asset_registry",
        "mock_price_oracle",
        "vault_registry",
        "rate_manager",
    ]
    for dep in dependencies:
        request.getfixturevalue(dep)
    reserve_manager = admin.deploy(ReserveManager, admin, gyro_config)
    gyro_config.setAddress(
        config_keys.RESERVE_MANAGER_ADDRESS, reserve_manager, {"from": admin}
    )
    return reserve_manager


@pytest.fixture(scope="module")
def static_percentage_fee_handler(StaticPercentageFeeHandler, admin, gyro_config):
    fee_handler = admin.deploy(StaticPercentageFeeHandler, admin)
    gyro_config.setAddress(
        config_keys.FEE_HANDLER_ADDRESS, fee_handler, {"from": admin}
    )
    return fee_handler


@pytest.fixture(scope="module")
def gyd_token(admin, GydToken, gyro_config, deploy_with_proxy):
    gyd_token = deploy_with_proxy(
        GydToken, lambda c: c.initialize.encode_input(admin, "GYD Token", "GYD")
    )
    gyro_config.setAddress(config_keys.GYD_TOKEN_ADDRESS, gyd_token, {"from": admin})
    return gyd_token


@pytest.fixture(scope="module")
def reserve(admin, Reserve, gyro_config, deploy_with_proxy):
    reserve = deploy_with_proxy(Reserve, lambda c: c.initialize.encode_input(admin))
    gyro_config.setAddress(config_keys.RESERVE_ADDRESS, reserve, {"from": admin})
    return reserve


@pytest.fixture(scope="module")
def gyd_recovery(admin, GydRecovery, gyro_config, mock_gyfi, treasury):
    gyd_recovery = admin.deploy(
        GydRecovery,
        admin,
        gyro_config,
        mock_gyfi,
        treasury,
        GYD_RECOVERY_WITHDRAWAL_WAIT_DURATION,
        GYD_RECOVERY_MAX_WITHDRAWAL_WAIT_DURATION,
        GYD_RECOVERY_MAX_TRIGGER_CR,
    )
    gyro_config.setAddress(
        config_keys.GYD_RECOVERY_ADDRESS, gyd_recovery, {"from": admin}
    )

    gyro_config.setUint(config_keys.GYD_RECOVERY_TRIGGER_CR, GYD_RECOVERY_TRIGGER_CR)
    gyro_config.setUint(config_keys.GYD_RECOVERY_TARGET_CR, GYD_RECOVERY_TARGET_CR)

    return gyd_recovery


@pytest.fixture(scope="module")
def mock_balancer_pool(admin, MockBalancerPool):
    return admin.deploy(MockBalancerPool, constants.BALANCER_POOL_ID)


@pytest.fixture(scope="module")
def mock_balancer_pool_two(admin, MockBalancerPool):
    return admin.deploy(MockBalancerPool, constants.BALANCER_POOL_ID_2)


@pytest.fixture(scope="module")
def mock_balancer_vault(admin, gyro_config, MockBalVault):
    bvault = admin.deploy(MockBalVault)
    gyro_config.setAddress(config_keys.BALANCER_VAULT_ADDRESS, bvault)
    return bvault


@pytest.fixture(scope="module")
def proxy_admin(admin, ProxyAdmin):
    return admin.deploy(ProxyAdmin)


@pytest.fixture(scope="module")
def deploy_with_proxy(admin, FreezableTransparentUpgradeableProxy, proxy_admin):
    def _deploy_with_proxy(Contract, initialize, *args):
        contract = admin.deploy(Contract, *args)
        proxy = admin.deploy(
            FreezableTransparentUpgradeableProxy,
            contract,
            proxy_admin,
            initialize(contract),
        )
        FreezableTransparentUpgradeableProxy.remove(proxy)
        contract = Contract.at(proxy, owner=admin)
        return contract

    return _deploy_with_proxy


@pytest.fixture(scope="module")
def gyro_config(admin, GyroConfig, deploy_with_proxy):
    config = deploy_with_proxy(GyroConfig, lambda c: c.initialize.encode_input(admin))
    config.setUint(
        config_keys.STABLECOIN_MAX_DEVIATION, constants.STABLECOIN_MAX_DEVIATION
    )
    return config


@pytest.fixture(scope="module")
def lp_token(Token):
    yield Token.deploy("LP Token", "LPT", 18, scale(10_000), {"from": accounts[0]})


@pytest.fixture(scope="module")
def mock_pamm(admin, MockPAMM, gyro_config):
    pamm = admin.deploy(MockPAMM)
    gyro_config.setAddress(config_keys.PAMM_ADDRESS, pamm, {"from": admin})
    gyro_config.setUint(config_keys.REDEEM_DISCOUNT_RATIO, 0, {"from": admin})
    return pamm


@pytest.fixture(scope="module")
def mock_price_oracle(admin, MockPriceOracle, gyro_config):
    mock_price_oracle = admin.deploy(MockPriceOracle)
    gyro_config.setAddress(
        config_keys.ROOT_PRICE_ORACLE_ADDRESS, mock_price_oracle, {"from": admin}
    )
    return mock_price_oracle


@pytest.fixture(scope="module")
def asset_registry(admin, AssetRegistry, deploy_with_proxy, gyro_config):
    asset_registry = deploy_with_proxy(
        AssetRegistry, lambda c: c.initialize.encode_input(admin), gyro_config
    )
    gyro_config.setAddress(
        config_keys.ASSET_REGISTRY_ADDRESS, asset_registry, {"from": admin}
    )
    return asset_registry


@pytest.fixture(scope="module")
def stewardship_incentives(ReserveStewardshipIncentives, admin, gyro_config, gyd_token):
    stewardship_incentives = admin.deploy(
        ReserveStewardshipIncentives, admin, gyro_config
    )
    gyro_config.setAddress(
        config_keys.STEWARDSHIP_INC_ADDRESS, stewardship_incentives, {"from": admin}
    )

    gyro_config.setUint(config_keys.STEWARDSHIP_INC_MIN_CR, STEWARDSHIP_INC_MIN_CR)
    gyro_config.setUint(config_keys.STEWARDSHIP_INC_DURATION, STEWARDSHIP_INC_DURATION)
    gyro_config.setUint(
        config_keys.STEWARDSHIP_INC_MAX_VIOLATIONS, STEWARDSHIP_INC_MAX_VIOLATIONS
    )

    return stewardship_incentives


@pytest.fixture(scope="module")
def coinbase_price_oracle(admin, TestingTrustedSignerPriceOracle, asset_registry):
    return admin.deploy(
        TestingTrustedSignerPriceOracle,
        asset_registry,
        constants.COINBASE_SIGNING_ADDRESS,
        True,
    )


@pytest.fixture(scope="module")
def local_signer_price_oracle(
    admin, TestingTrustedSignerPriceOracle, asset_registry, price_signer
):
    return admin.deploy(
        TestingTrustedSignerPriceOracle, asset_registry, price_signer, True
    )


@pytest.fixture(scope="module")
def chainlink_price_oracle(ChainlinkPriceOracle, admin):
    return admin.deploy(ChainlinkPriceOracle, admin)


@pytest.fixture(scope="module")
def crash_protected_chainlink_oracle(CrashProtectedChainlinkPriceOracle, admin):
    return admin.deploy(CrashProtectedChainlinkPriceOracle, admin)


@pytest.fixture(scope="module")
def rate_manager(admin, RateManager, gyro_config):
    manager = admin.deploy(RateManager, admin)
    gyro_config.setAddress(config_keys.RATE_MANAGER_ADDRESS, manager, {"from": admin})
    return manager


@pytest.fixture(scope="module")
def local_checked_price_oracle(admin, mock_price_oracle, CheckedPriceOracle):
    return admin.deploy(
        CheckedPriceOracle,
        admin,
        mock_price_oracle,
        mock_price_oracle,
        TokenAddresses.WETH,
    )


@pytest.fixture(scope="module")
def testing_checked_price_oracle(admin, mock_price_oracle, TestingCheckedPriceOracle):
    return admin.deploy(
        TestingCheckedPriceOracle,
        admin,
        mock_price_oracle,
        mock_price_oracle,
    )


@pytest.fixture(scope="module")
def mainnet_checked_price_oracle(
    admin,
    chainlink_price_oracle,
    uniswap_spot_price_oracle,
    CheckedPriceOracle,
):
    mainnet_checked_price_oracle = admin.deploy(
        CheckedPriceOracle,
        admin,
        chainlink_price_oracle,
        uniswap_spot_price_oracle,
        TokenAddresses.WETH,
    )
    # set the relative max epsilon slightly larger to avoid tests randomly failing
    mainnet_checked_price_oracle.setRelativeMaxEpsilon(scale("0.03"))
    return mainnet_checked_price_oracle


@pytest.fixture(scope="module")
def root_safety_check(admin, RootSafetyCheck, gyro_config):
    safety_check = admin.deploy(RootSafetyCheck, admin, gyro_config)
    gyro_config.setAddress(
        config_keys.ROOT_SAFETY_CHECK_ADDRESS, safety_check, {"from": admin}
    )
    return safety_check


@pytest.fixture(scope="module")
def motherboard(
    admin, Motherboard, gyro_config, gyd_token, reserve, deploy_with_proxy, request
):
    extra_dependencies = [
        "mock_pamm",
        "mock_price_oracle",
        "reserve_manager",
        "root_safety_check",
        "static_percentage_fee_handler",
        "mock_balancer_vault",
        "gyd_recovery",
        "stewardship_incentives",
        "rate_manager",
    ]
    for dep in extra_dependencies:
        request.getfixturevalue(dep)
    motherboard = deploy_with_proxy(
        Motherboard, lambda c: c.initialize.encode_input(admin), gyro_config
    )
    reserve.addManager(motherboard, {"from": admin})
    gyro_config.setAddress(
        config_keys.MOTHERBOARD_ADDRESS, motherboard, {"from": admin}
    )
    gyd_token.addMinter(motherboard, {"from": admin})
    return motherboard


@pytest.fixture(scope="module")
def pamm(admin, TestingPAMMV1, gyro_config):
    pamm = TestingPAMMV1.deploy(
        admin,
        gyro_config,
        PammParams(
            int(constants.ALPHA_MIN_REL),
            int(constants.XU_MAX_REL),
            int(constants.THETA_FLOOR),
            int(constants.OUTFLOW_MEMORY),
        ),
        {"from": admin},
    )
    gyro_config.setUint(config_keys.REDEEM_DISCOUNT_RATIO, 0, {"from": admin})
    return pamm


@pytest.fixture(scope="module")
def reserve_safety_manager(admin, TestingReserveSafetyManager):
    return admin.deploy(
        TestingReserveSafetyManager,
        admin,
        constants.MAX_ALLOWED_VAULT_DEVIATION,
        constants.MIN_TOKEN_PRICE,
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
def vault(admin, GenericVault, underlying, deploy_with_proxy, gyro_config):
    return deploy_with_proxy(
        GenericVault,
        lambda v: v.initialize.encode_input(
            underlying, admin, "Base Vault Token", "BVT"
        ),
        gyro_config,
    )


# NOTE: this is a vault that contains only USDC as underlying
# this is for testing purposes only
@pytest.fixture(scope="module")
def usdc_vault(admin, GenericVault, usdc, deploy_with_proxy, gyro_config):
    return deploy_with_proxy(
        GenericVault,
        lambda v: v.initialize.encode_input(usdc, admin, "USDC Vault", "gUSDC"),
        gyro_config,
    )


@pytest.fixture(scope="module")
def fusdc_vault(admin, GenericVault, fusdc, deploy_with_proxy, gyro_config):
    return deploy_with_proxy(
        GenericVault,
        lambda v: v.initialize.encode_input(fusdc, admin, "fUSDC Vault", "gfUSDC"),
        gyro_config,
    )


@pytest.fixture(scope="module")
def mock_vaults(admin, MockGyroVault, dai, deploy_with_proxy, gyro_config):
    return [
        deploy_with_proxy(MockGyroVault, lambda v: v.initialize.encode_input(dai))
        for _ in range(constants.RESERVE_VAULTS)
    ]


@pytest.fixture(scope="module")
def batch_vault_price_oracle(admin, TestingBatchVaultPriceOracle, mock_price_oracle):
    return admin.deploy(TestingBatchVaultPriceOracle, admin, mock_price_oracle)


# NOTE: this is a vault that contains only DAI as underlying
# this is for testing purposes only
@pytest.fixture(scope="module")
def dai_vault(admin, GenericVault, dai, deploy_with_proxy, gyro_config):
    return deploy_with_proxy(
        GenericVault,
        lambda v: v.initialize.encode_input(dai, admin, "DAI Vault", "gDAI"),
        gyro_config,
    )


@pytest.fixture(scope="module")
def balancer_vault(interface):
    return interface.IVault(constants.BALANCER_VAULT_ADDRESS)


@pytest.fixture(scope="module")
def vault_safety_mode(admin, VaultSafetyMode, request, gyro_config):
    request.getfixturevalue("motherboard")
    gyro_config.setUint(
        config_keys.SAFETY_BLOCKS_AUTOMATIC, constants.SAFETY_BLOCKS_AUTOMATIC
    )
    gyro_config.setUint(
        config_keys.SAFETY_BLOCKS_GUARDIAN, constants.SAFETY_BLOCKS_GUARDIAN
    )
    return admin.deploy(VaultSafetyMode, admin, gyro_config)


@pytest.fixture(scope="module")
def testing_fixed_point(admin, TestingFixedPoint):
    return admin.deploy(TestingFixedPoint)


@pytest.fixture(scope="module")
def set_mock_oracle_prices_usdc_dai(
    mock_price_oracle, usdc, usdc_vault, dai, dai_vault, admin
):
    mock_price_oracle.setUSDPrice(usdc, scale(1), {"from": admin})
    mock_price_oracle.setUSDPrice(usdc_vault, scale(1), {"from": admin})
    mock_price_oracle.setUSDPrice(dai, scale(1), {"from": admin})
    mock_price_oracle.setUSDPrice(dai_vault, scale(1), {"from": admin})


@pytest.fixture(scope="module")
def set_fees_usdc_dai(static_percentage_fee_handler, usdc_vault, dai_vault, admin):
    static_percentage_fee_handler.setVaultFees(usdc_vault, 0, 0, {"from": admin})
    static_percentage_fee_handler.setVaultFees(dai_vault, 0, 0, {"from": admin})


@pytest.fixture
def register_usdc_vault(reserve_manager, usdc_vault, admin):
    reserve_manager.setVaults(
        [
            VaultConfiguration(
                usdc_vault, PersistedVaultMetadata(int(scale(1)), int(scale(1)), 0, 0)
            )
        ],
        {"from": admin},
    )


@pytest.fixture
def register_usdc_and_dai_vaults(reserve_manager, usdc_vault, dai_vault, admin):
    reserve_manager.setVaults(
        [
            VaultConfiguration(
                dai_vault,
                PersistedVaultMetadata(int(scale(1)), int(scale("0.6")), 0, 0),
            ),
            VaultConfiguration(
                usdc_vault,
                PersistedVaultMetadata(int(scale(1)), int(scale("0.4")), 0, 0),
            ),
        ],
        {"from": admin},
    )


@pytest.fixture(scope="module")
def gov_treasury_registered(gov, gyro_config):
    gyro_config.setAddress(config_keys.GOV_TREASURY_ADDRESS, gov)
    return gov
