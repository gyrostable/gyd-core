from scripts.utils import (
    get_deployer,
    get_gyro_config,
    make_tx_params,
    with_deployed,
)
from brownie import ReserveStewardshipIncentives, GovernanceProxy  # type: ignore


@with_deployed(GovernanceProxy)
def main(governance_proxy):
    deployer = get_deployer()
    deployer.deploy(
        ReserveStewardshipIncentives,
        governance_proxy,
        get_gyro_config(),
        **make_tx_params(),
    )
