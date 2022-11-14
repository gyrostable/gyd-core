from brownie import network
from brownie import BalancerPoolVault, VaultRegistry, GyroConfig, ReserveManager  # type: ignore
from scripts.utils import (
    as_singleton,
    get_deployer,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.support import config_keys
from scripts.config import vaults


@with_gas_usage
@as_singleton(ReserveManager)
@with_deployed(VaultRegistry)
@with_deployed(GyroConfig)
def main(gyro_config, vault_registry):
    deployer = get_deployer()

    reserve_manager = deployer.deploy(ReserveManager, gyro_config, **make_tx_params())
    gyro_config.setAddress(
        config_keys.RESERVE_MANAGER_ADDRESS,
        reserve_manager,
        {"from": deployer, **make_tx_params()},
    )
    vault_registry.setReserveManagerAddress(
        reserve_manager, {"from": deployer, **make_tx_params()}
    )
