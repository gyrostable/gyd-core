from pprint import pprint
import time
from typing import Union
from brownie import BalancerPoolVault, StaticPercentageFeeHandler, network, interface, ChainlinkPriceOracle, BalancerECLPV2PriceOracle, GenericVault, CheckedPriceOracle  # type: ignore
from scripts.utils import get_deployer, make_tx_params, with_deployed, with_gas_usage
from scripts.config import vaults
from tests.support import constants
from tests.support.types import (
    GenericVaultToDeploy,
    PersistedVaultMetadata,
    PricedToken,
    VaultConfiguration,
    VaultToDeploy,
)


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


def get_balancer_vault_config(vault_address, time_of_calibration=None):
    if time_of_calibration is None:
        time_of_calibration = int(time.time())
    chainlink_oracle = ChainlinkPriceOracle[0]
    eclp_oracle = BalancerECLPV2PriceOracle[0]

    vault = interface.IGyroVault(vault_address)
    vault_to_deploy = _get_vault_to_deploy(vault.symbol())
    balancer_pool = interface.IBalancerPool(vault.underlying())
    pool_id = balancer_pool.getPoolId()
    balancer_vault = interface.IVault(constants.BALANCER_VAULT_ADDRESS)
    tokens = balancer_vault.getPoolTokens(pool_id)[0]
    prices = [
        PricedToken(
            tokenAddress=t, is_stable=True, price=chainlink_oracle.getPriceUSD(t)
        )
        for t in tokens
    ]
    vault_token_price = eclp_oracle.getPriceUSD(vault_address, prices)

    return _get_vault_configuration(vault_address, vault_to_deploy, vault_token_price)


def get_generic_vault_config(vault_address, time_of_calibration=None):
    if time_of_calibration is None:
        time_of_calibration = int(time.time())
    oracle = CheckedPriceOracle[0]

    vault = interface.IGyroVault(vault_address)
    vault_to_deploy = _get_vault_to_deploy(vault.symbol())
    vault_token_price = oracle.getPriceUSD(vault.underlying())
    return _get_vault_configuration(vault_address, vault_to_deploy, vault_token_price)


def _get_vault_configuration(
    vault_address,
    vault_to_deploy: Union[VaultToDeploy, GenericVaultToDeploy],
    vault_token_price: int,
):
    decimals = interface.IGyroVault(vault_address).decimals()
    scaled_vault_short_flow_threshold = vault_to_deploy.short_flow_threshold * 10 ** (
        18 + decimals
    )
    short_flow_threshold = scaled_vault_short_flow_threshold // vault_token_price

    vault_configuration = VaultConfiguration(
        vault_address=vault_address,
        metadata=PersistedVaultMetadata(
            price_at_calibration=vault_token_price,
            short_flow_memory=vault_to_deploy.short_flow_memory,
            short_flow_threshold=short_flow_threshold,
            time_of_calibration=int(time.time()),
            weight_at_calibration=vault_to_deploy.initial_weight,
            weight_at_previous_calibration=vault_to_deploy.initial_weight,
            weight_transition_duration=1,
        ),
    )
    pprint(vault_configuration)
    return vault_configuration


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


@with_gas_usage
def generic(name):
    vault_to_deploy = _get_vault_to_deploy(name)
    deployer = get_deployer()
    deployer.deploy(
        GenericVault,
        constants.MAINNET_GOVERNANCE_ADDRESS,
        vault_to_deploy.underlying,
        vault_to_deploy.name,
        vault_to_deploy.symbol,
        **make_tx_params()
    )


def _get_vault_to_deploy(name):
    vaults_to_deploy = vaults[network.chain.id]
    return [vault for vault in vaults_to_deploy if vault.symbol == name][0]
