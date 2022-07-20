from brownie import RootSafetyCheck, AssetRegistry, GyroConfig, ReserveSafetyManager, VaultSafetyMode  # type: ignore
from scripts.utils import (
    as_singleton,
    get_deployer,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.support import config_keys, constants
from tests.support.utils import scale


@with_gas_usage
@as_singleton(RootSafetyCheck)
@with_deployed(GyroConfig)
def root(gyro_config):
    deployer = get_deployer()
    safety_check = deployer.deploy(RootSafetyCheck, gyro_config, **make_tx_params())
    gyro_config.setAddress(
        config_keys.ROOT_SAFETY_CHECK_ADDRESS,
        safety_check,
        {"from": deployer, **make_tx_params()},
    )


@with_gas_usage
@as_singleton(ReserveSafetyManager)
@with_deployed(AssetRegistry)
def reserve_safety_manager(asset_registry):
    deployer = get_deployer()
    return deployer.deploy(
        ReserveSafetyManager,
        scale("0.2"),  # large deviation to avoid failing test because of price changes
        constants.STABLECOIN_MAX_DEVIATION,
        constants.MIN_TOKEN_PRICE,
        asset_registry,
        **make_tx_params(),
    )


@with_gas_usage
@as_singleton(VaultSafetyMode)
@with_deployed(GyroConfig)
def vault_safety_mode(gyro_config):
    deployer = get_deployer()

    deployer.deploy(
        VaultSafetyMode,
        constants.SAFETY_BLOCKS_AUTOMATIC,
        constants.SAFETY_BLOCKS_GUARDIAN,
        gyro_config,
        **make_tx_params(),
    )


@with_gas_usage
@with_deployed(VaultSafetyMode)
@with_deployed(ReserveSafetyManager)
@with_deployed(RootSafetyCheck)
def register(root_safety_check, reserve_safety_manager, vault_safety_mode):
    deployer = get_deployer()
    root_safety_check.addCheck(
        vault_safety_mode, {"from": deployer, **make_tx_params()}
    )
    root_safety_check.addCheck(
        reserve_safety_manager, {"from": deployer, **make_tx_params()}
    )