from scripts.utils import (
    get_dao_treasury,
    get_deployer,
    get_gyfi_token,
    get_gyro_config,
    make_tx_params,
    with_deployed,
)
from brownie import GydRecovery, GyroConfig, GovernanceProxy
from tests.support import config_keys
from tests.support import constants  # type: ignore

from tests.support.constants import (
    GYD_RECOVERY_MAX_TRIGGER_CR,
    GYD_RECOVERY_MAX_WITHDRAWAL_WAIT_DURATION,
    GYD_RECOVERY_WITHDRAWAL_WAIT_DURATION,
    MAINNET_GOVERNANCE_ADDRESS,
)


@with_deployed(GyroConfig)
@with_deployed(GovernanceProxy)
def main(governance_proxy, gyro_config):
    deployer = get_deployer()
    gyd_recovery = deployer.deploy(
        GydRecovery,
        MAINNET_GOVERNANCE_ADDRESS,
        get_gyro_config(),
        get_gyfi_token(),
        get_dao_treasury(),
        GYD_RECOVERY_WITHDRAWAL_WAIT_DURATION,
        GYD_RECOVERY_MAX_WITHDRAWAL_WAIT_DURATION,
        GYD_RECOVERY_MAX_TRIGGER_CR,
        **make_tx_params(),
    )

    governance_proxy.executeCall(
        gyro_config,
        gyro_config.setAddress.encode_input(
            config_keys.GYD_RECOVERY_ADDRESS, gyd_recovery
        ),
        {"from": deployer, **make_tx_params()},
    )

    governance_proxy.executeCall(
        gyro_config,
        gyro_config.setUint.encode_input(
            config_keys.GYD_RECOVERY_TARGET_CR, constants.GYD_RECOVERY_TARGET_CR
        ),
        {"from": deployer, **make_tx_params()},
    )

    governance_proxy.executeCall(
        gyro_config,
        gyro_config.setUint.encode_input(
            config_keys.GYD_RECOVERY_TRIGGER_CR, constants.GYD_RECOVERY_TRIGGER_CR
        ),
        {"from": deployer, **make_tx_params()},
    )
