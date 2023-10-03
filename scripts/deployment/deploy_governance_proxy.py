from brownie import ProxyAdmin, GovernanceProxy  # type: ignore
from scripts.utils import (
    as_singleton,
    deploy_proxy,
    get_deployer,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)


@with_gas_usage
@with_deployed(GovernanceProxy)
@with_deployed(ProxyAdmin)
def proxy(proxy_admin, governance_proxy):
    deployer = get_deployer()
    proxy = deploy_proxy(
        governance_proxy,
        init_data=governance_proxy.initialize.encode_input(deployer),
    )
    proxy_admin.transferOwnership(proxy, {"from": deployer, **make_tx_params()})


@with_gas_usage
@as_singleton(GovernanceProxy)
def main():
    deployer = get_deployer()
    deployer.deploy(GovernanceProxy, **make_tx_params(), publish_source=True)
