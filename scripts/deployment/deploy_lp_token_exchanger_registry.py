from brownie import GyroConfig, LPTokenExchangerRegistry  # type: ignore

from scripts.utils import (
    get_deployer,
    as_singleton,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.support import config_keys


@with_gas_usage
@as_singleton(LPTokenExchangerRegistry)
@with_deployed(GyroConfig)
def main(gyro_config):
    deployer = get_deployer()
    exchanger_registry = deployer.deploy(LPTokenExchangerRegistry, **make_tx_params())
    gyro_config.setAddress(
        config_keys.EXCHANGER_REGISTRY_ADDRESS,
        exchanger_registry,
        {"from": deployer, **make_tx_params()},
    )
    return exchanger_registry
