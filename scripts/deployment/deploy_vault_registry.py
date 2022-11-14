from brownie import GyroConfig, VaultRegistry  # type: ignore
from scripts.utils import (
    get_deployer,
    make_tx_params,
    with_deployed,
    with_gas_usage,
    as_singleton,
)
from tests.support import config_keys


@with_gas_usage
@with_deployed(GyroConfig)
@as_singleton(VaultRegistry)
def main(gyro_config):
    deployer = get_deployer()
    vault_registry = deployer.deploy(VaultRegistry, gyro_config, **make_tx_params())
    gyro_config.setAddress(
        config_keys.VAULT_REGISTRY_ADDRESS,
        vault_registry,
        {"from": deployer, **make_tx_params()},
    )
