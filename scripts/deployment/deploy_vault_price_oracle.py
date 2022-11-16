from brownie import GenericVaultPriceOracle, BalancerCEMMPriceOracle, BalancerCPMMPriceOracle, BalancerCPMMV2PriceOracle, BalancerCPMMV3PriceOracle  # type: ignore
from scripts.utils import as_singleton, get_deployer, with_gas_usage


@with_gas_usage
@as_singleton(GenericVaultPriceOracle)
def generic():
    get_deployer().deploy(GenericVaultPriceOracle)


@with_gas_usage
@as_singleton(BalancerCPMMPriceOracle)
def cpmm():
    get_deployer().deploy(BalancerCPMMPriceOracle)


@with_gas_usage
@as_singleton(BalancerCPMMV2PriceOracle)
def cpmm_v2():
    get_deployer().deploy(BalancerCPMMV2PriceOracle)


@with_gas_usage
@as_singleton(BalancerCPMMV3PriceOracle)
def cpmm_v3():
    get_deployer().deploy(BalancerCPMMV3PriceOracle)


@with_gas_usage
@as_singleton(BalancerCEMMPriceOracle)
def cemm():
    get_deployer().deploy(BalancerCEMMPriceOracle)
