from brownie import MockPriceOracle, BatchVaultPriceOracle  # type: ignore

from scripts.utils import get_deployer, with_deployed
from tests.support.types import VaultType


@with_deployed(BatchVaultPriceOracle)
def main(batch_vault_price_oracle):
    deployer = get_deployer()
    oracle = deployer.deploy(MockPriceOracle)
    batch_vault_price_oracle.setBatchPriceOracle(oracle, {"from": deployer})
