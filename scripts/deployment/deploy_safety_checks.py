from brownie import RootSafetyCheck, GovernanceProxy, GyroConfig, ReserveSafetyManager, VaultSafetyMode  # type: ignore
from scripts.utils import (
    as_singleton,
    deploy_proxy,
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
@with_deployed(GovernanceProxy)
def root(governance_proxy, gyro_config):
    deployer = get_deployer()
    safety_check = deployer.deploy(
        RootSafetyCheck, governance_proxy, gyro_config, **make_tx_params()
    )
    governance_proxy.executeCall(
        gyro_config,
        gyro_config.setAddress.encode_input(
            config_keys.ROOT_SAFETY_CHECK_ADDRESS, safety_check
        ),
        {"from": deployer, **make_tx_params()},
    )


@with_gas_usage
@as_singleton(ReserveSafetyManager)
@with_deployed(GovernanceProxy)
def reserve_safety_manager(governance_proxy):
    deployer = get_deployer()
    return deployer.deploy(
        ReserveSafetyManager,
        governance_proxy,
        scale("0.1"),
        constants.STABLECOIN_MAX_DEVIATION,
        constants.MIN_TOKEN_PRICE,
        **make_tx_params(),
    )


@with_gas_usage
@as_singleton(VaultSafetyMode)
@with_deployed(GyroConfig)
@with_deployed(GovernanceProxy)
def vault_safety_mode(governance_proxy, gyro_config):
    deployer = get_deployer()

    deployer.deploy(
        VaultSafetyMode,
        governance_proxy,
        constants.SAFETY_BLOCKS_AUTOMATIC,
        constants.SAFETY_BLOCKS_GUARDIAN,
        gyro_config,
        **make_tx_params(),
    )


@with_gas_usage
@with_deployed(VaultSafetyMode)
@with_deployed(ReserveSafetyManager)
@with_deployed(RootSafetyCheck)
@with_deployed(GovernanceProxy)
def register(
    governance_proxy, root_safety_check, reserve_safety_manager, vault_safety_mode
):
    deployer = get_deployer()
    governance_proxy.executeCall(
        root_safety_check,
        root_safety_check.addCheck.encode_input(vault_safety_mode),
        {"from": deployer, **make_tx_params()},
    )
    governance_proxy.executeCall(
        root_safety_check,
        root_safety_check.addCheck.encode_input(reserve_safety_manager),
        {"from": deployer, **make_tx_params()},
    )
