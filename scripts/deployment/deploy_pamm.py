from brownie import GyroConfig, PrimaryAMMV1  # type: ignore
from scripts.utils import (
    as_singleton,
    get_deployer,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.support import config_keys, constants
from tests.support.types import PammParams


@with_gas_usage
@as_singleton(PrimaryAMMV1)
@with_deployed(GyroConfig)
def main(gyro_config):
    deployer = get_deployer()
    pamm = deployer.deploy(
        PrimaryAMMV1,
        gyro_config,
        PammParams(
            alpha_bar=int(constants.ALPHA_MIN_REL),
            xu_bar=int(constants.XU_MAX_REL),
            theta_bar=int(constants.THETA_FLOOR),
            outflow_memory=int(constants.OUTFLOW_MEMORY),
        ),
    )
    gyro_config.setAddress(
        config_keys.PAMM_ADDRESS, pamm, {"from": deployer, **make_tx_params()}
    )
