from brownie import Motherboard, GyroConfig, Reserve  # type: ignore
from scripts.utils import (
    as_singleton,
    get_deployer,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.support import config_keys


@with_gas_usage
@as_singleton(Motherboard)
@with_deployed(GyroConfig)
@with_deployed(Reserve)
def main(reserve, gyro_config):
    deployer = get_deployer()

    motherboard = deployer.deploy(Motherboard, gyro_config, **make_tx_params())
    reserve.addManager(motherboard, {"from": deployer, **make_tx_params()})
    gyro_config.setAddress(
        config_keys.MOTHERBOARD_ADDRESS,
        motherboard,
        {"from": deployer, **make_tx_params()},
    )
