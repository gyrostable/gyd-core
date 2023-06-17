from scripts.utils import (
    get_deployer,
    get_gyfi_token,
    get_gyro_config,
    make_tx_params,
    with_deployed,
)
from brownie import GydRecovery, GovernanceProxy

from tests.support.constants import GYD_RECOVERY_MAX_TRIGGER_CR, GYD_RECOVERY_MAX_WITHDRAWAL_WAIT_DURATION, GYD_RECOVERY_WITHDRAWAL_WAIT_DURATION  # type: ignore


@with_deployed(GovernanceProxy)
def main(governance_proxy):
    deployer = get_deployer()
    deployer.deploy(
        GydRecovery,
        governance_proxy,
        get_gyro_config(),
        get_gyfi_token(),
        GYD_RECOVERY_WITHDRAWAL_WAIT_DURATION,
        GYD_RECOVERY_MAX_WITHDRAWAL_WAIT_DURATION,
        GYD_RECOVERY_MAX_TRIGGER_CR,
        **make_tx_params(),
    )
