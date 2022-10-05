from brownie import GyroConfig, VaultRegistry  # type: ignore
from scripts.utils import (
    get_deployer,
    make_tx_params,
    with_deployed,
    with_gas_usage,
    as_singleton,
)


@with_gas_usage
@with_deployed(GyroConfig)
@as_singleton(VaultRegistry)
def main(gyro_config):
    deployer = get_deployer()
    deployer.deploy(VaultRegistry, gyro_config, **make_tx_params())
