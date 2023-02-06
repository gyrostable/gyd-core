from brownie import GenericVaultPriceOracle, BalancerECLPPriceOracle, BalancerCPMMPriceOracle, Balancer2CLPPriceOracle, Balancer3CLPPriceOracle  # type: ignore
from scripts.utils import as_singleton, get_deployer, make_tx_params, with_gas_usage


@with_gas_usage
@as_singleton(GenericVaultPriceOracle)
def generic():
    get_deployer().deploy(GenericVaultPriceOracle, **make_tx_params())


@with_gas_usage
@as_singleton(BalancerCPMMPriceOracle)
def cpmm():
    get_deployer().deploy(BalancerCPMMPriceOracle, **make_tx_params())


@with_gas_usage
def g2clp():
    get_deployer().deploy(Balancer2CLPPriceOracle, **make_tx_params())


@with_gas_usage
def g3clp():
    get_deployer().deploy(Balancer3CLPPriceOracle, **make_tx_params())


@with_gas_usage
def eclp():
    get_deployer().deploy(BalancerECLPPriceOracle, **make_tx_params())
