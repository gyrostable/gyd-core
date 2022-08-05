from brownie import GyroConfig, FreezableTransparentUpgradeableProxy, ProxyAdmin  # type: ignore
from scripts.utils import (
    get_deployer,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)


@with_gas_usage
@with_deployed(GyroConfig)
@with_deployed(ProxyAdmin)
def main(proxy_admin, gyro_config):
    deployer = get_deployer()
    deployer.deploy(
        FreezableTransparentUpgradeableProxy,
        gyro_config,
        proxy_admin,
        gyro_config.initialize.encode_input(deployer),
        **make_tx_params(),
    )
