from brownie import CapAuthentication, GyroConfig  # type: ignore

from scripts.utils import (
    get_deployer,
    as_singleton,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.support import config_keys


@with_gas_usage
@as_singleton(CapAuthentication)
@with_deployed(GyroConfig)
def main(gyro_config):
    deployer = get_deployer()
    cap_authentication = deployer.deploy(CapAuthentication, **make_tx_params())
    gyro_config.setAddress(
        config_keys.CAP_AUTHENTICATION_ADDRESS,
        cap_authentication,
        {"from": deployer, **make_tx_params()},
    )
