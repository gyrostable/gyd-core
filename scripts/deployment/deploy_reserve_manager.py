from brownie import network
from brownie import BalancerPoolVault, VaultRegistry, GyroConfig, ReserveManager  # type: ignore
from scripts.utils import as_singleton, get_deployer, with_deployed, with_gas_usage
from tests.support import config_keys
from scripts.config import vaults


@with_gas_usage
@as_singleton(ReserveManager)
@with_deployed(VaultRegistry)
@with_deployed(GyroConfig)
def main(gyro_config, vault_registry):
    deployer = get_deployer()

    reserve_manager = deployer.deploy(ReserveManager, gyro_config)
    gyro_config.setAddress(config_keys.RESERVE_MANAGER_ADDRESS, reserve_manager)
    vault_registry.setReserveManagerAddress(reserve_manager, {"from": deployer})
    for i, vault in enumerate(vaults[network.chain.id]):
        reserve_manager.registerVault(
            BalancerPoolVault[i],
            vault.initial_weight,
            vault.short_flow_memory,
            vault.short_flow_threshold,
        )
