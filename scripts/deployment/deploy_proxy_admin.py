from brownie import GovernanceProxy, ProxyAdmin  # type: ignore
from scripts.utils import (
    as_singleton,
    get_deployer,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)


@with_gas_usage
@as_singleton(ProxyAdmin)
def main():
    deployer = get_deployer()
    deployer.deploy(ProxyAdmin, **make_tx_params(), publish_source=True)
