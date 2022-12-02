import os
import brownie
from brownie import GovernanceProxy, BalancerPoolVault, GenericVault  # type: ignore
from scripts.utils import get_deployer, with_deployed, with_gas_usage
from tests.support.types import VaultType
from tests.support.utils import scale
from tests.fixtures.mainnet_contracts import TokenAddresses

OUTFLOW_MEMORY = 999993123563518195

POLYGON_3CLP_USDC_BUSD_USDT_ADDRESS = "0x17f1Ef81707811eA15d9eE7c741179bbE2A63887"
POLYGON_ECLP_TUSD_USDC_ADDRESS = "0x97469E6236bD467cd147065f77752b00EfadCe8a"
POLYGON_2CLP_USDC_DAI_ADDRESS = "0xf16a66320Fafe03c9bf6daaAEBE9418f17620de6"


vaults = [
    {
        "name": "Gyro 2CLP USDC/DAI vault",
        "symbol": "gv-2CLP-USDC-DAI",
        "vault_type": VaultType.BALANCER_2CLP,
        "vault_contract": "BalancerPoolVault",
        "underlying_address": POLYGON_2CLP_USDC_DAI_ADDRESS,
        "mint_fee": 0,
        "redeem_fee": 0,
        "short_flow_memory": int(OUTFLOW_MEMORY),
        "short_flow_threshold": int(scale(1_000)),
        "initial_weight": int(scale(1) / 3) + 1,
    },
    {
        "name": "Gyro ECLP TUSD/USDC vault",
        "symbol": "gv-ECLP-TUSD-USDC",
        "vault_contract": "BalancerPoolVault",
        "underlying_address": POLYGON_ECLP_TUSD_USDC_ADDRESS,
        "mint_fee": 0,
        "redeem_fee": 0,
        "short_flow_memory": int(OUTFLOW_MEMORY),
        "short_flow_threshold": int(scale(1_000)),
        "initial_weight": int(scale(1) / 3),
    },
    {
        "name": "Gyro 3CLP USDC/BUSD/USDT vault",
        "symbol": "gv-3CLP-USDC-BUSD-USDT",
        "vault_contract": "BalancerPoolVault",
        "underlying_address": POLYGON_3CLP_USDC_BUSD_USDT_ADDRESS,
        "mint_fee": 0,
        "redeem_fee": 0,
        "short_flow_memory": int(OUTFLOW_MEMORY),
        "short_flow_threshold": int(scale(1_000)),
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


@with_gas_usage
@with_deployed(GovernanceProxy)
def main():
    vault_symbol = os.environ.get("VAULT_SYMBOL")
    assert vault_symbol, "VAULT_SYMBOL not set"

    vault_info = [v for v in vaults if v["symbol"] == vault_symbol][0]
    Vault = getattr(brownie, vault_info["vault_contract"])
