from brownie import GovernanceProxy, GyroConfig, CheckedPriceOracle, GenericVaultPriceOracle, BatchVaultPriceOracle  # type: ignore
from brownie import BalancerCPMMPriceOracle, Balancer2CLPPriceOracle, Balancer3CLPPriceOracle, BalancerECLPPriceOracle  # type: ignore
from scripts.utils import (
    as_singleton,
    get_deployer,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.support import config_keys
from tests.support.types import VaultType


@with_gas_usage
@with_deployed(BatchVaultPriceOracle)
@with_deployed(GenericVaultPriceOracle)
@with_deployed(BalancerCPMMPriceOracle)
@with_deployed(Balancer2CLPPriceOracle)
@with_deployed(Balancer3CLPPriceOracle)
@with_deployed(BalancerECLPPriceOracle)
@with_deployed(GovernanceProxy)
def initialize(
    governance_proxy,
    balancer_eclp_price_oracle,
    balancer_3clp_price_oracle,
    balancer_2clp_price_oracle,
    balancer_cpmm_price_oracle,
    generic_vault_price_oracle,
    batch_vault_price_oracle,
):
    deployer = get_deployer()

    governance_proxy.executeCall(
        batch_vault_price_oracle,
        batch_vault_price_oracle.registerVaultPriceOracle.encode_input(
            VaultType.GENERIC, generic_vault_price_oracle
        ),
        {"from": deployer, **make_tx_params()},
    )
    governance_proxy.executeCall(
        batch_vault_price_oracle,
        batch_vault_price_oracle.registerVaultPriceOracle.encode_input(
            VaultType.BALANCER_CPMM, balancer_cpmm_price_oracle
        ),
        {"from": deployer, **make_tx_params()},
    )

    governance_proxy.executeCall(
        batch_vault_price_oracle,
        batch_vault_price_oracle.registerVaultPriceOracle.encode_input(
            VaultType.BALANCER_2CLP, balancer_2clp_price_oracle
        ),
        {"from": deployer, **make_tx_params()},
    )
    governance_proxy.executeCall(
        batch_vault_price_oracle,
        batch_vault_price_oracle.registerVaultPriceOracle.encode_input(
            VaultType.BALANCER_3CLP, balancer_3clp_price_oracle
        ),
        {"from": deployer, **make_tx_params()},
    )

    governance_proxy.executeCall(
        batch_vault_price_oracle,
        batch_vault_price_oracle.registerVaultPriceOracle.encode_input(
            VaultType.BALANCER_ECLP, balancer_eclp_price_oracle
        ),
        {"from": deployer, **make_tx_params()},
    )


@with_gas_usage
@as_singleton(BatchVaultPriceOracle)
@with_deployed(CheckedPriceOracle)
@with_deployed(GyroConfig)
@with_deployed(GovernanceProxy)
def main(governance_proxy, gyro_config, full_checked_price_oracle):
    deployer = get_deployer()
    oracle = deployer.deploy(
        BatchVaultPriceOracle,
        governance_proxy,
        full_checked_price_oracle,
        **make_tx_params()
    )
    governance_proxy.executeCall(
        gyro_config,
        gyro_config.setAddress.encode_input(
            config_keys.ROOT_PRICE_ORACLE_ADDRESS,
            oracle,
        ),
        {"from": deployer, **make_tx_params()},
    )
