from brownie import GyroConfig, ReserveManager, GovernanceProxy  # type: ignore
from scripts.utils import (
    as_singleton,
    get_deployer,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.support import config_keys
from tests.support.constants import MAINNET_GOVERNANCE_ADDRESS


@with_gas_usage
@as_singleton(ReserveManager)
@with_deployed(GyroConfig)
@with_deployed(GovernanceProxy)
def main(governance_proxy, gyro_config):
    deployer = get_deployer()

    reserve_manager = deployer.deploy(
        ReserveManager, MAINNET_GOVERNANCE_ADDRESS, gyro_config, **make_tx_params()
    )
    governance_proxy.executeCall(
        gyro_config,
        gyro_config.setAddress.encode_input(
            config_keys.RESERVE_MANAGER_ADDRESS, reserve_manager
        ),
        {"from": deployer, **make_tx_params()},
    )
