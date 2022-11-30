from brownie import GydToken, GyroConfig  # type: ignore
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
@with_deployed(GydToken)
def proxy(gyd_token):
    deploy_proxy(
        gyd_token,
        config_key=config_keys.GYD_TOKEN_ADDRESS,
        init_data=gyd_token.initialize.encode_input("GYD Token", "GYD"),
    )


@with_gas_usage
@as_singleton(GydToken)
@with_deployed(GyroConfig)
def main(gyro_config):
    deployer = get_deployer()
    deployer.deploy(GydToken, gyro_config, **make_tx_params())
