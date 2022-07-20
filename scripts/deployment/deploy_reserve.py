from brownie import GyroConfig, Reserve  # type: ignore
from scripts.utils import (
    as_singleton,
    get_deployer,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.support import config_keys


@with_gas_usage
@as_singleton(Reserve)
@with_deployed(GyroConfig)
def main(gyro_config):
    deployer = get_deployer()
    reserve = deployer.deploy(Reserve, **make_tx_params())
    gyro_config.setAddress(
        config_keys.RESERVE_ADDRESS, reserve, {"from": deployer, **make_tx_params()}
    )
