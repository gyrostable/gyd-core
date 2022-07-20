from brownie import FeeBank, GyroConfig  # type: ignore
from scripts.utils import (
    as_singleton,
    get_deployer,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.support import config_keys


@with_gas_usage
@as_singleton(FeeBank)
@with_deployed(GyroConfig)
def main(gyro_config):
    deployer = get_deployer()

    fee_bank = deployer.deploy(
        FeeBank,
        **make_tx_params(),
    )
    gyro_config.setAddress(
        config_keys.FEE_BANK_ADDRESS, fee_bank, {"from": deployer, **make_tx_params()}
    )
