from scripts.utils import (
    get_deployer,
    get_gyro_config,
    make_tx_params,
    with_deployed,
)
from brownie import ReserveStewardshipIncentives, GovernanceProxy, GyroConfig
from tests.support import config_keys
from tests.support import constants  # type: ignore

from tests.support.constants import MAINNET_GOVERNANCE_ADDRESS


@with_deployed(GovernanceProxy)
@with_deployed(GyroConfig)
def main(gyro_config, governance_proxy):
    deployer = get_deployer()
    reserve_stewardship_incentives = deployer.deploy(
        ReserveStewardshipIncentives,
        MAINNET_GOVERNANCE_ADDRESS,
        get_gyro_config(),
        **make_tx_params(),
    )

    governance_proxy.executeCall(
        gyro_config,
        gyro_config.setAddress.encode_input(
            config_keys.STEWARDSHIP_INC_ADDRESS, reserve_stewardship_incentives
        ),
        {"from": deployer, **make_tx_params()},
    )

    governance_proxy.executeCall(
        gyro_config,
        gyro_config.setUint.encode_input(
            config_keys.STEWARDSHIP_INC_DURATION, constants.STEWARDSHIP_INC_DURATION
        ),
        {"from": deployer, **make_tx_params()},
    )

    governance_proxy.executeCall(
        gyro_config,
        gyro_config.setUint.encode_input(
            config_keys.STEWARDSHIP_INC_MAX_VIOLATIONS,
            constants.STEWARDSHIP_INC_MAX_VIOLATIONS,
        ),
        {"from": deployer, **make_tx_params()},
    )

    governance_proxy.executeCall(
        gyro_config,
        gyro_config.setUint.encode_input(
            config_keys.STEWARDSHIP_INC_MIN_CR, constants.STEWARDSHIP_INC_MIN_CR
        ),
        {"from": deployer, **make_tx_params()},
    )
