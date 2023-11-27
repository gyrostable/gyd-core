from brownie import GydToken, GyroConfig  # type: ignore
from scripts.utils import (
    as_singleton,
    deploy_proxy,
    get_deployer,
    get_token_name_and_symbol,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.support import config_keys
from tests.support.constants import MAINNET_GOVERNANCE_ADDRESS


@with_gas_usage
@with_deployed(GydToken)
def proxy(gyd_token):
    token_name, token_symbol = get_token_name_and_symbol()
    deploy_proxy(
        gyd_token,
        config_key=config_keys.GYD_TOKEN_ADDRESS,
        init_data=gyd_token.initialize.encode_input(
            MAINNET_GOVERNANCE_ADDRESS, token_name, token_symbol
        ),
    )


@with_gas_usage
@as_singleton(GydToken)
def main():
    deployer = get_deployer()
    deployer.deploy(GydToken, **make_tx_params())
