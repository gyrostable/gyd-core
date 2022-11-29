from brownie import GyroConfig  # type: ignore

from scripts.utils import (
    deploy_proxy,
    get_deployer,
    as_singleton,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.support import config_keys, constants


@with_gas_usage
@with_deployed(GyroConfig)
def set_initial_config(gyro_config):
    deployer = get_deployer()
    gyro_config.setUint(
        config_keys.GYD_GLOBAL_SUPPLY_CAP,
        constants.GYD_GLOBAL_SUPPLY_CAP,
        {"from": deployer, **make_tx_params()},
    )

    gyro_config.setUint(
        config_keys.GYD_AUTHENTICATED_USER_CAP,
        constants.GYD_AUTHENTICATED_USER_CAP,
        {"from": deployer, **make_tx_params()},
    )

    gyro_config.setUint(
        config_keys.GYD_USER_CAP,
        constants.GYD_USER_CAP,
        {"from": deployer, **make_tx_params()},
    )


@with_gas_usage
@with_deployed(GyroConfig)
def proxy(gyro_config):
    deployer = get_deployer()
    deploy_proxy(gyro_config, gyro_config.initialize.encode_input(deployer))


@with_gas_usage
@as_singleton(GyroConfig)
def main():
    deployer = get_deployer()
    deployer.deploy(GyroConfig, **make_tx_params())
