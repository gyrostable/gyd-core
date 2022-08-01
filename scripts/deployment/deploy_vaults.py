from brownie import BalancerPoolVault, StaticPercentageFeeHandler, network  # type: ignore
from scripts.utils import get_deployer, with_deployed, with_gas_usage
from scripts.config import vaults
from tests.support import constants


@with_gas_usage
@with_deployed(StaticPercentageFeeHandler)
def set_fees(static_percentage_fee_handler):
    vaults_to_deploy = vaults[network.chain.id]
    deployer = get_deployer()
    for i, vault in enumerate(vaults_to_deploy):
        static_percentage_fee_handler.setVaultFees(
            BalancerPoolVault[i],
            vault.mint_fee,
            vault.redeem_fee,
            {"from": deployer},
        )


@with_gas_usage
def main():
    vaults_to_deploy = vaults[network.chain.id]
    deployer = get_deployer()
    for vault_to_deploy in vaults_to_deploy:
        deployer.deploy(
            BalancerPoolVault,
            vault_to_deploy.vault_type,
            constants.BALANCER_POOL_IDS["WETH_DAI"],
            constants.BALANCER_VAULT_ADDRESS,
            vault_to_deploy.name,
            vault_to_deploy.symbol,
        )
