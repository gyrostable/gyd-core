from brownie import GyroConfig, StaticPercentageFeeHandler  # type: ignore

from scripts.utils import get_deployer, make_tx_params, with_deployed, with_gas_usage
from tests.support import config_keys


@with_gas_usage
@with_deployed(GyroConfig)
def main(gyro_config):
    deployer = get_deployer()

    fee_handler = deployer.deploy(StaticPercentageFeeHandler, **make_tx_params())
    gyro_config.setAddress(
        config_keys.FEE_HANDLER_ADDRESS,
        fee_handler,
        {"from": deployer, **make_tx_params()},
    )
