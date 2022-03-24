from typing import List
import pytest
from tests.fixtures.mainnet_contracts import (
    CHAINLINK_FEEDS,
    TokenAddresses,
    UniswapPools,
    is_stable,
)
from tests.support import config_keys, constants
from tests.support.retrieve_coinbase_prices import fetch_prices, find_price
from tests.support.types import PammParams, VaultToDeploy, VaultType
from tests.support.utils import scale

OUTFLOW_MEMORY = 999993123563518195


@pytest.fixture(scope="module")
def mainnet_asset_registry(admin, asset_registry):
    asset_registry.setAssetAddress("ETH", TokenAddresses.WETH, {"from": admin})
    asset_registry.setAssetAddress("DAI", TokenAddresses.DAI, {"from": admin})
    asset_registry.setAssetAddress("WBTC", TokenAddresses.WBTC, {"from": admin})
    asset_registry.setAssetAddress("USDC", TokenAddresses.USDC, {"from": admin})
    asset_registry.setAssetAddress("USDT", TokenAddresses.USDT, {"from": admin})

    asset_registry.addStableAsset(TokenAddresses.USDT, {"from": admin})
    asset_registry.addStableAsset(TokenAddresses.USDC, {"from": admin})
    asset_registry.addStableAsset(TokenAddresses.DAI, {"from": admin})

    return asset_registry


@pytest.fixture(scope="module")
def mainnet_reserve_manager(
    admin,
    ReserveManager,
    gyro_config,
    request,
    vault_registry,
    mainnet_vaults: List[VaultToDeploy],
):
    dependencies = [
        "reserve",
        "mainnet_batch_vault_price_oracle",
    ]
    for dep in dependencies:
        request.getfixturevalue(dep)
    reserve_manager = admin.deploy(ReserveManager, gyro_config)
    gyro_config.setAddress(config_keys.RESERVE_MANAGER_ADDRESS, reserve_manager)
    vault_registry.setReserveManagerAddress(reserve_manager, {"from": admin})
    for vault in mainnet_vaults:
        reserve_manager.registerVault(
            vault.address,
            vault.initial_weight,
            vault.short_flow_memory,
            vault.short_flow_threshold,
        )

    return reserve_manager


@pytest.fixture(scope="module")
def add_common_uniswap_pools(admin, uniswap_v3_twap_oracle):
    pools = [
        getattr(UniswapPools, v) for v in dir(UniswapPools) if not v.startswith("_")
    ]
    for pool in pools:
        uniswap_v3_twap_oracle.registerPool(pool, {"from": admin})


@pytest.fixture(scope="module")
def set_common_chainlink_feeds(
    admin, chainlink_price_oracle, crash_protected_chainlink_oracle
):
    for asset, feed in CHAINLINK_FEEDS:
        chainlink_price_oracle.setFeed(asset, feed, {"from": admin})
        min_diff_time = 3_600
        max_deviation = scale("0.01" if is_stable(asset) else "0.05")
        crash_protected_chainlink_oracle.setFeed(
            asset, feed, (min_diff_time, max_deviation), {"from": admin}
        )


@pytest.fixture(scope="module")
def set_mainnet_fees(mainnet_vaults, static_percentage_fee_handler, admin):
    for vault in mainnet_vaults:
        static_percentage_fee_handler.setVaultFees(
            vault.address, vault.mint_fee, vault.redeem_fee, {"from": admin}
        )


@pytest.fixture(scope="module")
def mainnet_vaults(BalancerPoolVault, admin, balancer_vault):
    return [
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


@pytest.fixture(scope="module")
def mainnet_batch_vault_price_oracle(
    BatchVaultPriceOracle,
    admin,
    full_checked_price_oracle,
    gyro_config,
    balancer_cpmm_price_oracle,
):
    oracle = admin.deploy(BatchVaultPriceOracle, full_checked_price_oracle)
    gyro_config.setAddress(
        config_keys.ROOT_PRICE_ORACLE_ADDRESS,
        oracle,
        {"from": admin},
    )
    oracle.registerVaultPriceOracle(
        VaultType.BALANCER_CPMM, balancer_cpmm_price_oracle, {"from": admin}
    )
    return oracle


@pytest.fixture(scope="module")
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


@pytest.fixture(scope="module")
def mainnet_coinbase_price_oracle(
    admin, TrustedSignerPriceOracle, mainnet_asset_registry
):
    oracle = admin.deploy(
        TrustedSignerPriceOracle,
        mainnet_asset_registry,
        constants.COINBASE_SIGNING_ADDRESS,
    )

    eth_price = find_price(fetch_prices()[0], "ETH")
    oracle.postPrices([eth_price], {"from": admin})
    return oracle


@pytest.fixture(scope="module")
def mainnet_pamm(admin, PrimaryAMMV1, gyro_config):
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
    return pamm


@pytest.fixture(scope="module")
def mainnet_vault_safety_mode(admin, VaultSafetyMode, gyro_config):
    return admin.deploy(
        VaultSafetyMode,
        constants.SAFETY_BLOCKS_AUTOMATIC,
        constants.SAFETY_BLOCKS_GUARDIAN,
        gyro_config,
    )


@pytest.fixture(scope="module")
def mainnet_reserve_safety_manager(admin, ReserveSafetyManager, mainnet_asset_registry):
    return admin.deploy(
        ReserveSafetyManager,
        scale("0.2"),  # large deviation to avoid failing test because of price changes
        constants.STABLECOIN_MAX_DEVIATION,
        constants.MIN_TOKEN_PRICE,
        mainnet_asset_registry,
    )


@pytest.fixture(scope="module")
def initialize_safety_checks(
    root_safety_check, mainnet_vault_safety_mode, mainnet_reserve_safety_manager, admin
):
    root_safety_check.addCheck(mainnet_vault_safety_mode, {"from": admin})
    root_safety_check.addCheck(mainnet_reserve_safety_manager, {"from": admin})


@pytest.fixture(scope="module")
def uninitialized_motherboard(admin, Motherboard, request, gyro_config, reserve):
    extra_dependencies = [
        "gyd_token",
        "fee_bank",
    ]
    for dep in extra_dependencies:
        request.getfixturevalue(dep)
    motherboard = admin.deploy(Motherboard, gyro_config)
    reserve.addManager(motherboard, {"from": admin})
    gyro_config.setAddress(config_keys.MOTHERBOARD_ADDRESS, motherboard)
    return motherboard


@pytest.fixture(scope="module")
def full_motherboard(uninitialized_motherboard, request):
    extra_dependencies = [
        "lp_token_exchanger_registry",
        "set_common_chainlink_feeds",
        "add_common_uniswap_pools",
        "mainnet_batch_vault_price_oracle",
        "mainnet_reserve_manager",
        "mainnet_pamm",
        "initialize_safety_checks",
        "set_mainnet_fees",
    ]
    for dep in extra_dependencies:
        request.getfixturevalue(dep)
    return uninitialized_motherboard
