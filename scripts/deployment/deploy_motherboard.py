from brownie import Motherboard, GyroConfig, Reserve  # type: ignore
from scripts.utils import (
    as_singleton,
    deploy_proxy,
    get_deployer,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.support import config_keys


@with_gas_usage
@with_deployed(Motherboard)
@with_deployed(Reserve)
def proxy(reserve, motherboard):
    deployer = get_deployer()
    deploy_proxy(
        motherboard,
        config_key=config_keys.MOTHERBOARD_ADDRESS,
        init_data=motherboard.initialize.encode_input(deployer),
    )
    reserve.addManager(motherboard, {"from": deployer, **make_tx_params()})


@with_gas_usage
@as_singleton(Motherboard)
@with_deployed(GyroConfig)
def main(gyro_config):
    deployer = get_deployer()
    deployer.deploy(Motherboard, gyro_config, **make_tx_params())
