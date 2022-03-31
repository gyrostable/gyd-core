from brownie import GydToken, GyroConfig  # type: ignore
from scripts.utils import (
    as_singleton,
    get_deployer,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.support import config_keys


@with_gas_usage
@as_singleton(GydToken)
@with_deployed(GyroConfig)
def main(gyro_config):
    deployer = get_deployer()

    gyd_token = deployer.deploy(
        GydToken, gyro_config, "GYD Token", "GYD", **make_tx_params()
    )
    gyro_config.setAddress(
        config_keys.GYD_TOKEN_ADDRESS, gyd_token, {"from": deployer, **make_tx_params()}
    )
