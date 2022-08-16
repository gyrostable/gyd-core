from brownie import GyroConfig  # type: ignore

from scripts.utils import (
    get_deployer,
    as_singleton,
    make_tx_params,
    with_gas_usage,
)


@with_gas_usage
@as_singleton(GyroConfig)
def main():
    deployer = get_deployer()
    config = deployer.deploy(GyroConfig, **make_tx_params())
    config.initialize(deployer, {"from": deployer, **make_tx_params()})
