from brownie import CapAuthentication  # type: ignore

from scripts.utils import (
    deploy_proxy,
    get_deployer,
    as_singleton,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.support import config_keys


@with_gas_usage
@with_deployed(CapAuthentication)
def proxy(cap_authentication):
    deploy_proxy(
        cap_authentication,
        cap_authentication.initialize.encode_input(),
        config_keys.CAP_AUTHENTICATION_ADDRESS,
    )


@with_gas_usage
@as_singleton(CapAuthentication)
def main():
    deployer = get_deployer()
    deployer.deploy(CapAuthentication, **make_tx_params())
