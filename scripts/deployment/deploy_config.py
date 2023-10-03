from brownie import GyroConfig, GovernanceProxy  # type: ignore

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
@with_deployed(GovernanceProxy)
def set_initial_config(governance_proxy, gyro_config):
    deployer = get_deployer()
    governance_proxy.executeCall(
        gyro_config,
        gyro_config.setUint.encode_input(
            config_keys.GYD_GLOBAL_SUPPLY_CAP, constants.GYD_GLOBAL_SUPPLY_CAP
        ),
        {"from": deployer, **make_tx_params()},
    )

    governance_proxy.executeCall(
        gyro_config,
        gyro_config.setUint.encode_input(
            config_keys.GYD_AUTHENTICATED_USER_CAP, constants.GYD_AUTHENTICATED_USER_CAP
        ),
        {"from": deployer, **make_tx_params()},
    )

    governance_proxy.executeCall(
        gyro_config,
        gyro_config.setUint.encode_input(
            config_keys.GYD_USER_CAP, constants.GYD_USER_CAP
        ),
        {"from": deployer, **make_tx_params()},
    )

    governance_proxy.executeCall(
        gyro_config,
        gyro_config.setAddress.encode_input(
            config_keys.BALANCER_VAULT_ADDRESS, constants.BALANCER_VAULT_ADDRESS
        ),
        {"from": deployer, **make_tx_params()},
    )


@with_gas_usage
@with_deployed(GyroConfig)
@with_deployed(GovernanceProxy)
def proxy(governance_proxy, gyro_config):
    deploy_proxy(gyro_config, gyro_config.initialize.encode_input(governance_proxy))


@with_gas_usage
@as_singleton(GyroConfig)
def main():
    deployer = get_deployer()
    deployer.deploy(GyroConfig, **make_tx_params(), publish_source=True)
