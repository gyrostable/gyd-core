from brownie import GyroConfig, FreezableTransparentUpgradeableProxy, ProxyAdmin  # type: ignore
from scripts.utils import (
    as_singleton,
    get_deployer,
    make_tx_params,
    with_gas_usage,
)


@with_gas_usage
@as_singleton(ProxyAdmin)
def main():
    get_deployer().deploy(ProxyAdmin, **make_tx_params())
