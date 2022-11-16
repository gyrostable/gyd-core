from brownie import GyroConfig, CheckedPriceOracle, GenericVaultPriceOracle, BatchVaultPriceOracle  # type: ignore
from brownie import BalancerCPMMPriceOracle, BalancerCPMMV2PriceOracle, BalancerCPMMV3PriceOracle, BalancerCEMMPriceOracle  # type: ignore
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
@with_deployed(BalancerCPMMV2PriceOracle)
@with_deployed(BalancerCPMMV3PriceOracle)
@with_deployed(BalancerCEMMPriceOracle)
def initialize(
    balancer_cemm_price_oracle,
    balancer_cpmm_v3_price_oracle,
    balancer_cpmm_v2_price_oracle,
    balancer_cpmm_price_oracle,
    generic_vault_price_oracle,
    batch_vault_price_oracle,
):
    deployer = get_deployer()
    batch_vault_price_oracle.registerVaultPriceOracle(
        VaultType.GENERIC,
        generic_vault_price_oracle,
        {"from": deployer, **make_tx_params()},
    )
    batch_vault_price_oracle.registerVaultPriceOracle(
        VaultType.BALANCER_CPMM,
        balancer_cpmm_price_oracle,
        {"from": deployer, **make_tx_params()},
    )
    batch_vault_price_oracle.registerVaultPriceOracle(
        VaultType.BALANCER_CPMM,
        balancer_cpmm_v2_price_oracle,
        {"from": deployer, **make_tx_params()},
    )
    batch_vault_price_oracle.registerVaultPriceOracle(
        VaultType.BALANCER_CPMM,
        balancer_cpmm_v3_price_oracle,
        {"from": deployer, **make_tx_params()},
    )
    batch_vault_price_oracle.registerVaultPriceOracle(
        VaultType.BALANCER_CPMM,
        balancer_cemm_price_oracle,
        {"from": deployer, **make_tx_params()},
    )


@with_gas_usage
@as_singleton(BatchVaultPriceOracle)
@with_deployed(CheckedPriceOracle)
@with_deployed(GyroConfig)
def main(gyro_config, full_checked_price_oracle):
    deployer = get_deployer()
    oracle = deployer.deploy(BatchVaultPriceOracle, full_checked_price_oracle)
    gyro_config.setAddress(
        config_keys.ROOT_PRICE_ORACLE_ADDRESS,
        oracle,
        {"from": deployer, **make_tx_params()},
    )
