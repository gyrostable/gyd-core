import json
from brownie import GovernanceProxy, GyroConfig, CheckedPriceOracle, GenericVaultPriceOracle, BatchVaultPriceOracle  # type: ignore
from brownie import BalancerCPMMPriceOracle, Balancer2CLPPriceOracle, Balancer3CLPPriceOracle, BalancerECLPPriceOracle  # type: ignore
from scripts.utils import (
    as_singleton,
    get_deployer,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.support import config_keys, constants
from tests.support.types import VaultType


@with_deployed(BatchVaultPriceOracle)
@with_deployed(GenericVaultPriceOracle)
@with_deployed(BalancerCPMMPriceOracle)
@with_deployed(Balancer2CLPPriceOracle)
@with_deployed(Balancer3CLPPriceOracle)
@with_deployed(BalancerECLPPriceOracle)
@with_deployed(GyroConfig)
def initialize(
    gyro_config,
    balancer_eclp_price_oracle,
    balancer_3clp_price_oracle,
    balancer_2clp_price_oracle,
    balancer_cpmm_price_oracle,
    generic_vault_price_oracle,
    batch_vault_price_oracle,
):
    calls = []

    calls.append(
        (
            batch_vault_price_oracle.address,
            batch_vault_price_oracle.registerVaultPriceOracle.encode_input(
                VaultType.GENERIC, generic_vault_price_oracle
            ),
        )
    )
    calls.append(
        (
            batch_vault_price_oracle.address,
            batch_vault_price_oracle.registerVaultPriceOracle.encode_input(
                VaultType.BALANCER_CPMM, balancer_cpmm_price_oracle
            ),
        )
    )

    calls.append(
        (
            batch_vault_price_oracle.address,
            batch_vault_price_oracle.registerVaultPriceOracle.encode_input(
                VaultType.BALANCER_2CLP, balancer_2clp_price_oracle
            ),
        )
    )
    calls.append(
        (
            batch_vault_price_oracle.address,
            batch_vault_price_oracle.registerVaultPriceOracle.encode_input(
                VaultType.BALANCER_3CLP, balancer_3clp_price_oracle
            ),
        )
    )

    calls.append(
        (
            batch_vault_price_oracle.address,
            batch_vault_price_oracle.registerVaultPriceOracle.encode_input(
                VaultType.BALANCER_ECLP, balancer_eclp_price_oracle
            ),
        )
    )

    calls.append(
        (
            gyro_config.address,
            gyro_config.setAddress.encode_input(
                config_keys.ROOT_PRICE_ORACLE_ADDRESS,
                batch_vault_price_oracle,
            ),
        )
    )

    print(json.dumps(calls))


@with_gas_usage
@as_singleton(BatchVaultPriceOracle)
@with_deployed(CheckedPriceOracle)
def main(full_checked_price_oracle):
    deployer = get_deployer()
    deployer.deploy(
        BatchVaultPriceOracle,
        constants.MAINNET_GOVERNANCE_ADDRESS,
        full_checked_price_oracle,
        **make_tx_params()
    )
