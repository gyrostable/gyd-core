from brownie import BalancerPoolVault, StaticPercentageFeeHandler, network, GenericVault  # type: ignore
from scripts.utils import get_deployer, make_tx_params, with_deployed, with_gas_usage
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


# def set_vaults():
#     vaults_to_deploy = vaults[network.chain.id]
#     deployer = get_deployer()


@with_gas_usage
def balancer(name):
    vault_to_deploy = _get_vault_to_deploy(name)
    deployer = get_deployer()
    deployer.deploy(
        BalancerPoolVault,
        constants.MAINNET_GOVERNANCE_ADDRESS,
        vault_to_deploy.vault_type,
        vault_to_deploy.pool_id,
        constants.BALANCER_VAULT_ADDRESS,
        vault_to_deploy.name,
        vault_to_deploy.symbol,
        **make_tx_params()
    )


def _get_vault_to_deploy(name):
    vaults_to_deploy = vaults[network.chain.id]
    return [vault for vault in vaults_to_deploy if vault.symbol == name][0]
