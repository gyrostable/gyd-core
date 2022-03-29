from brownie import (
    GyroConfig,
    LPTokenExchangerRegistry,
    ChainlinkPriceOracle,
    CrashProtectedChainlinkOracle,
    UniswapV3TwapPriceOracle,
    BatchVaultPriceOracle,
    BalancerCPMMPriceOracle,
    Reserve,
    ReserveManager,
    VaultRegistry,
    BalancerPoolVault,
    PrimaryAMMV1,
    RootSafetyCheck,
    StaticPercentageFeeHandler,
    GydToken,
    FeeBank,
    Motherboard,
)
from scripts.utils import (
    get_deployer,
)
from tests.fixtures.mainnet_contracts import (
    CHAINLINK_FEEDS,
    TokenAddresses,
    UniswapPools,
    is_stable,
)
from tests.support import config_keys, constants
from tests.support.types import PammParams, VaultToDeploy, VaultType
from tests.support.utils import scale

OUTFLOW_MEMORY = 999993123563518195


def main():
    admin = get_deployer()

    # Find relevant contracts
    gyro_config = GyroConfig[-1]
    chainlink_price_oracle = ChainlinkPriceOracle[-1]
    crash_protected_chainlink_oracle = CrashProtectedChainlinkOracle[-1]
    uniswap_v3_twap_oracle = UniswapV3TwapPriceOracle[-1]
    balancer_cpmm_price_oracle = BalancerCPMMPriceOracle[-1]
    vault_registry = VaultRegistry[-1]
    balancer_vault = "0xBA12222222228d8Ba445958a75a0704d566BF2C8"

    # LPTokenExchangerRegistry
    exchanger_registry = admin.deploy(LPTokenExchangerRegistry)
    gyro_config.setAddress(config_keys.EXCHANGER_REGISTRY_ADDRESS, exchanger_registry)

    # Set Common Chainlink Feeds
    for asset, feed in CHAINLINK_FEEDS:
        chainlink_price_oracle.setFeed(asset, feed, {"from": admin})
        min_diff_time = 3_600
        max_deviation = scale("0.01" if is_stable(asset) else "0.05")
        crash_protected_chainlink_oracle.setFeed(
            asset, feed, (min_diff_time, max_deviation), {"from": admin}
        )

    # Add Common Uniswap Pools
    pools = [
        getattr(UniswapPools, v) for v in dir(UniswapPools) if not v.startswith("_")
    ]
    for pool in pools:
        uniswap_v3_twap_oracle.registerPool(pool, {"from": admin})

    # Mainnet batch vault price oracle
    def full_checked_price_oracle(
        admin,
        crash_protected_chainlink_oracle,
        uniswap_v3_twap_oracle,
        mainnet_coinbase_price_oracle,
        CheckedPriceOracle,
    ):
        mainnet_checked_price_oracle = admin.deploy(
            CheckedPriceOracle, crash_protected_chainlink_oracle, uniswap_v3_twap_oracle
        )
        mainnet_checked_price_oracle.addSignedPriceSource(
            mainnet_coinbase_price_oracle, {"from": admin}
        )
        mainnet_checked_price_oracle.addQuoteAssetsForPriceLevelTwap(
            TokenAddresses.USDC, {"from": admin}
        )
        mainnet_checked_price_oracle.addQuoteAssetsForPriceLevelTwap(
            TokenAddresses.USDT, {"from": admin}
        )
        mainnet_checked_price_oracle.addQuoteAssetsForPriceLevelTwap(
            TokenAddresses.DAI, {"from": admin}
        )

        return mainnet_checked_price_oracle

    oracle = admin.deploy(BatchVaultPriceOracle, full_checked_price_oracle)
    gyro_config.setAddress(
        config_keys.ROOT_PRICE_ORACLE_ADDRESS,
        oracle,
        {"from": admin},
    )
    oracle.registerVaultPriceOracle(
        VaultType.BALANCER_CPMM, balancer_cpmm_price_oracle, {"from": admin}
    )

    # Mainnet reserve manager
    reserve = admin.deploy(Reserve)
    gyro_config.setAddress(config_keys.RESERVE_ADDRESS, reserve)

    reserve_manager = admin.deploy(ReserveManager, gyro_config)
    gyro_config.setAddress(config_keys.RESERVE_MANAGER_ADDRESS, reserve_manager)
    vault_registry.setReserveManagerAddress(reserve_manager, {"from": admin})

    mainnet_vaults = [
        VaultToDeploy(
            pool=constants.address_from_pool_id(
                constants.BALANCER_POOL_IDS["WETH_DAI"]
            ),
            address=admin.deploy(
                BalancerPoolVault,
                VaultType.BALANCER_CPMM,
                constants.BALANCER_POOL_IDS["WETH_DAI"],
                balancer_vault,
                "Balancer CPMM WETH-DAI",
                "BAL-CPMM-WETH-DAI",
            ).address,
            initial_weight=int(scale("0.5")),
            short_flow_memory=OUTFLOW_MEMORY,
            short_flow_threshold=int(scale(1_000_000)),
            mint_fee=int(scale("0.005")),
            redeem_fee=int(scale("0.01")),
        ),
        VaultToDeploy(
            pool=constants.address_from_pool_id(
                constants.BALANCER_POOL_IDS["WETH_USDC"]
            ),
            address=admin.deploy(
                BalancerPoolVault,
                VaultType.BALANCER_CPMM,
                constants.BALANCER_POOL_IDS["WETH_USDC"],
                balancer_vault,
                "Balancer CPMM WETH-USDC",
                "BAL-CPMM-WETH-USDC",
            ).address,
            initial_weight=int(scale("0.4")),
            short_flow_memory=OUTFLOW_MEMORY,
            short_flow_threshold=int(scale(1_000_000)),
            mint_fee=int(scale("0.002")),
            redeem_fee=int(scale("0.005")),
        ),
        VaultToDeploy(
            pool=constants.address_from_pool_id(
                constants.BALANCER_POOL_IDS["WBTC_WETH"]
            ),
            address=admin.deploy(
                BalancerPoolVault,
                VaultType.BALANCER_CPMM,
                constants.BALANCER_POOL_IDS["WBTC_WETH"],
                balancer_vault,
                "Balancer CPMM WBTC-WETH",
                "BAL-CPMM-WBTC-WETH",
            ).address,
            initial_weight=int(scale("0.1")),
            short_flow_memory=OUTFLOW_MEMORY,
            short_flow_threshold=int(scale(1_000_000)),
            mint_fee=int(scale("0.004")),
            redeem_fee=int(scale("0.015")),
        ),
    ]

    for vault in mainnet_vaults:
        reserve_manager.registerVault(
            vault.address,
            vault.initial_weight,
            vault.short_flow_memory,
            vault.short_flow_threshold,
        )

    # Mainnet PAMM
    pamm = admin.deploy(
        PrimaryAMMV1,
        gyro_config,
        PammParams(
            alpha_bar=int(constants.ALPHA_MIN_REL),
            xu_bar=int(constants.XU_MAX_REL),
            theta_bar=int(constants.THETA_FLOOR),
            outflow_memory=OUTFLOW_MEMORY,
        ),
    )
    gyro_config.setAddress(config_keys.PAMM_ADDRESS, pamm)

    # Add safety checks
    root_safety_check = admin.deploy(RootSafetyCheck, gyro_config)
    gyro_config.setAddress(config_keys.ROOT_SAFETY_CHECK_ADDRESS, root_safety_check)

    def mainnet_vault_safety_mode(admin, VaultSafetyMode, gyro_config):
        return admin.deploy(
            VaultSafetyMode,
            constants.SAFETY_BLOCKS_AUTOMATIC,
            constants.SAFETY_BLOCKS_GUARDIAN,
            gyro_config,
        )

    def mainnet_reserve_safety_manager(
        admin, ReserveSafetyManager, mainnet_asset_registry
    ):
        return admin.deploy(
            ReserveSafetyManager,
            scale(
                "0.2"
            ),  # large deviation to avoid failing test because of price changes
            constants.STABLECOIN_MAX_DEVIATION,
            constants.MIN_TOKEN_PRICE,
            mainnet_asset_registry,
        )

    root_safety_check.addCheck(mainnet_vault_safety_mode, {"from": admin})
    root_safety_check.addCheck(mainnet_reserve_safety_manager, {"from": admin})

    # Set mainnet fees

    static_percentage_fee_handler = admin.deploy(StaticPercentageFeeHandler)
    gyro_config.setAddress(
        config_keys.FEE_HANDLER_ADDRESS, static_percentage_fee_handler
    )

    for vault in mainnet_vaults:
        static_percentage_fee_handler.setVaultFees(
            vault.address, vault.mint_fee, vault.redeem_fee, {"from": admin}
        )

    # GYD token
    gyd_token = admin.deploy(GydToken, gyro_config, "GYD Token", "GYD")
    gyro_config.setAddress(config_keys.GYD_TOKEN_ADDRESS, gyd_token)

    # Fee bank
    fee_bank = admin.deploy(FeeBank)
    gyro_config.setAddress(config_keys.FEE_BANK_ADDRESS, fee_bank)

    # Motherboard
    motherboard = admin.deploy(Motherboard, gyro_config)
    reserve.addManager(motherboard, {"from": admin})
    gyro_config.setAddress(config_keys.MOTHERBOARD_ADDRESS, motherboard)
    return motherboard
