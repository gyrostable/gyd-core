import os
from brownie import ReserveManager, GovernanceProxy, BalancerPoolVault, GenericVault, StaticPercentageFeeHandler  # type: ignore
from scripts.utils import get_deployer, make_tx_params, with_deployed, with_gas_usage
from tests.support import constants
from tests.support.types import VaultType
from tests.support.utils import scale
from tests.fixtures.mainnet_contracts import TokenAddresses

OUTFLOW_MEMORY = 999993123563518195

POLYGON_3CLP_USDC_BUSD_USDT_POOL_ID = (
    "0x17f1ef81707811ea15d9ee7c741179bbe2a63887000100000000000000000799"
)
POLYGON_ECLP_TUSD_USDC_POOL_ID = (
    "0x97469e6236bd467cd147065f77752b00efadce8a0002000000000000000008c0"
)
POLYGON_2CLP_USDC_DAI_POOL_ID = (
    "0xf16a66320fafe03c9bf6daaaebe9418f17620de60002000000000000000008e1"
)

GV_2CLP_USDC_DAI_PER_USD = 400416022433178311987
GV_ECLP_TUSD_USDC_PER_USD = 566252610024670
GV_3CLP_USDC_BUSD_USDT_PER_USD = 1994750994494982116993

vaults = [
    {
        "name": "Gyro 2CLP USDC/DAI vault",
        "symbol": "gv-2CLP-USDC-DAI",
        "vault_type": VaultType.BALANCER_2CLP,
        "vault_contract": "BalancerPoolVault",
        "pool_id": POLYGON_2CLP_USDC_DAI_POOL_ID,
        "mint_fee": 0,
        "redeem_fee": 0,
        "short_flow_memory": int(OUTFLOW_MEMORY),
        "short_flow_threshold": 1000 * GV_2CLP_USDC_DAI_PER_USD,
        "initial_weight": int(scale(1) / 3) + 1,
    },
    {
        "name": "Gyro ECLP TUSD/USDC vault",
        "symbol": "gv-ECLP-TUSD-USDC",
        "vault_contract": "BalancerPoolVault",
        "vault_type": VaultType.BALANCER_ECLP,
        "pool_id": POLYGON_ECLP_TUSD_USDC_POOL_ID,
        "mint_fee": 0,
        "redeem_fee": 0,
        "short_flow_memory": int(OUTFLOW_MEMORY),
        "short_flow_threshold": 1000 * GV_ECLP_TUSD_USDC_PER_USD,
        "initial_weight": int(scale(1) / 3),
    },
    {
        "name": "Gyro 3CLP USDC/BUSD/USDT vault",
        "symbol": "gv-3CLP-USDC-BUSD-USDT",
        "vault_contract": "BalancerPoolVault",
        "vault_type": VaultType.BALANCER_3CLP,
        "pool_id": POLYGON_3CLP_USDC_BUSD_USDT_POOL_ID,
        "mint_fee": 0,
        "redeem_fee": 0,
        "short_flow_memory": int(OUTFLOW_MEMORY),
        "short_flow_threshold": 1000 * GV_3CLP_USDC_BUSD_USDT_PER_USD,
        "initial_weight": int(scale(1) / 3),
    },
    {
        "name": "Gyro WETH vault",
        "symbol": "gv-WETH",
        "vault_contract": "GenericVault",
        "underlying_address": TokenAddresses.WETH,
        "mint_fee": 0,
        "redeem_fee": 0,
        "short_flow_memory": int(OUTFLOW_MEMORY),
        "short_flow_threshold": int(scale(1)),
        "initial_weight": 0,
    },
]


def get_vault_info():
    vault_symbol = os.environ.get("VAULT_SYMBOL")
    assert vault_symbol, "VAULT_SYMBOL not set"
    matches = [v for v in vaults if v["symbol"] == vault_symbol]
    if not matches:
        raise ValueError(f"Vault {vault_symbol} not found")
    return matches[0]


@with_gas_usage
@with_deployed(StaticPercentageFeeHandler)
@with_deployed(GovernanceProxy)
def set_fees(governance_proxy, static_percentage_fee_handler):
    vault_address = os.environ.get("VAULT_ADDRESS")
    assert vault_address, "VAULT_ADDRESS not set"

    deployer = get_deployer()
    vault_info = get_vault_info()
    governance_proxy.executeCall(
        static_percentage_fee_handler,
        static_percentage_fee_handler.setVaultFees.encode_input(
            vault_address, vault_info["mint_fee"], vault_info["redeem_fee"]
        ),
        {"from": deployer, **make_tx_params()},
    )


@with_gas_usage
@with_deployed(GovernanceProxy)
@with_deployed(ReserveManager)
def register(reserve_manager, governance_proxy):
    vault_address = os.environ.get("VAULT_ADDRESS")
    assert vault_address, "VAULT_ADDRESS not set"

    deployer = get_deployer()
    vault_info = get_vault_info()

    governance_proxy.executeCall(
        reserve_manager,
        reserve_manager.registerVault.encode_input(
            vault_address,
            vault_info["initial_weight"],
            vault_info["short_flow_memory"],
            vault_info["short_flow_threshold"],
        ),
        {"from": deployer, **make_tx_params()},
    )


@with_gas_usage
@with_deployed(GovernanceProxy)
def deploy(governance_proxy):
    deployer = get_deployer()

    vault_info = get_vault_info()
    if vault_info["vault_contract"] == "BalancerPoolVault":
        deployer.deploy(
            BalancerPoolVault,
            governance_proxy,
            vault_info["vault_type"],
            vault_info["pool_id"],
            constants.BALANCER_VAULT_ADDRESS,  # type: ignore
            vault_info["name"],
            vault_info["symbol"],
            **make_tx_params(),
        )
    elif vault_info["vault_contract"] == "GenericVault":
        deployer.deploy(
            GenericVault,
            governance_proxy,
            vault_info["underlying_address"],
            vault_info["name"],
            vault_info["symbol"],
            **make_tx_params(),
        )
    else:
        raise ValueError(f"Unknown vault contract {vault_info['vault_contract']}")
