import json
from os import path
from pprint import pprint
import time
from typing import Union
from brownie import BalancerPoolVault, StaticPercentageFeeHandler, network, interface, ChainlinkPriceOracle  # type: ignore
from brownie import BalancerECLPPriceOracle, GenericVault, CheckedPriceOracle, GovernanceProxy, ReserveManager  # type: ignore
from scripts.utils import (
    deploy_proxy,
    get_deployer,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from scripts.config import vaults
from tests.support import constants
from tests.support.types import (
    GenericVaultToDeploy,
    PersistedVaultMetadata,
    PricedToken,
    VaultConfiguration,
    VaultToDeploy,
    VaultType,
)

ROOT_DIR = path.dirname(path.dirname(path.dirname(__file__)))


@with_gas_usage
@with_deployed(StaticPercentageFeeHandler)
@with_deployed(GovernanceProxy)
def set_fees(governance_proxy, static_percentage_fee_handler):
    deployer = get_deployer()
    vault_addresses = _get_all_vault_addresses()
    symbols = [interface.ERC20(v).symbol() for v in vault_addresses]
    for vault_address, vault_symbol in zip(vault_addresses, symbols):
        vault_config = _get_vault_to_deploy(vault_symbol)
        governance_proxy.executeCall(
            static_percentage_fee_handler,
            static_percentage_fee_handler.setVaultFees.encode_input(
                vault_address,
                vault_config.mint_fee,
                vault_config.redeem_fee,
            ),
            {"from": deployer, **make_tx_params()},
        )


@with_deployed(ReserveManager)
def set_vaults(reserve_manager):
    vault_addresses = _get_all_vault_addresses()
    current_time = int(time.time())
    configs = [get_vault_config(v, current_time) for v in vault_addresses]
    with open(path.join(ROOT_DIR, "config", f"vaults-{current_time}.json"), "w") as f:
        json.dump([c.as_dict() for c in configs], f, indent=2)
    deployer = get_deployer()
    reserve_manager.setVaults(configs, {"from": deployer, **make_tx_params()})
    # print("Encoded data:")
    # print(
    #     json.dumps(
    #         [(reserve_manager.address, reserve_manager.setVaults.encode_input(configs))]
    #     )
    # )


def get_vault_config(vault_address, time_of_calibration=None):
    vault = interface.IGyroVault(vault_address)
    vault_type = vault.vaultType()
    if vault_type == VaultType.GENERIC:
        return get_generic_vault_config(vault_address, time_of_calibration)
    else:
        return get_balancer_vault_config(vault_address, time_of_calibration)


def get_balancer_vault_config(vault_address, time_of_calibration=None):
    if time_of_calibration is None:
        time_of_calibration = int(time.time())
    chainlink_oracle = ChainlinkPriceOracle[0]
    eclp_oracle = BalancerECLPPriceOracle[0]

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
    vault = deployer.deploy(
        BalancerPoolVault,
        vault_to_deploy.vault_type,
        constants.BALANCER_VAULT_ADDRESS,
        **make_tx_params(),
    )
    deploy_proxy(
        vault,
        vault.initialize.encode_input(
            vault_to_deploy.pool_id,
            constants.MAINNET_GOVERNANCE_ADDRESS,
            vault_to_deploy.name,
            vault_to_deploy.symbol,
        ),
        overwrite_proxy=True,
    )


@with_gas_usage
def generic(name):
    vault_to_deploy = _get_vault_to_deploy(name)
    deployer = get_deployer()
    vault = deployer.deploy(GenericVault, **make_tx_params())
    deploy_proxy(
        vault,
        vault.initialize.encode_input(
            vault_to_deploy.underlying,
            constants.MAINNET_GOVERNANCE_ADDRESS,
            vault_to_deploy.name,
            vault_to_deploy.symbol,
        ),
        overwrite_proxy=True,
    )


def _get_vault_to_deploy(name):
    vaults_to_deploy = vaults[network.chain.id]
    return [vault for vault in vaults_to_deploy if vault.symbol == name][0]


def _get_all_vault_addresses():
    return [v.address for v in list(GenericVault) + list(BalancerPoolVault)]
