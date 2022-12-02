from brownie import GyroConfig, Reserve  # type: ignore
from scripts.utils import (
    as_singleton,
    deploy_proxy,
    get_deployer,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.support import config_keys


@with_gas_usage
@with_deployed(Reserve)
def proxy(reserve):
    deploy_proxy(
        reserve,
        config_key=config_keys.RESERVE_ADDRESS,
        init_data=reserve.initialize.encode_input(get_deployer()),
    )


@with_gas_usage
@as_singleton(Reserve)
def main():
    deployer = get_deployer()
    deployer.deploy(Reserve, **make_tx_params())
