from brownie import GovernanceProxy, MockPriceOracle, BatchVaultPriceOracle  # type: ignore

from scripts.utils import get_deployer, with_deployed


@with_deployed(BatchVaultPriceOracle)
@with_deployed(GovernanceProxy)
def main(governance_proxy, batch_vault_price_oracle):
    deployer = get_deployer()
    oracle = deployer.deploy(MockPriceOracle)
    governance_proxy.executeCall(
        batch_vault_price_oracle,
        batch_vault_price_oracle.setBatchPriceOracle.encode_input(oracle),
        {"from": deployer},
    )
