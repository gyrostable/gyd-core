from brownie import GenericVault, Token, StaticPercentageFeeHandler, ReserveManager, MockPriceOracle  # type: ignore
from scripts.utils import get_deployer, with_deployed, with_gas_usage
from tests.support.utils import scale
from tests.support import constants


vaults = [
    {
        "underlying": {
            "name": "DAI Stablecoin",
            "symbol": "DAI",
            "decimals": 18,
            "price": scale(1),
        },
        "mint_fee": scale("0.0005"),
        "redeem_fee": scale("0.001"),
        "short_flow_memory": int(constants.OUTFLOW_MEMORY),
        "short_flow_threshold": int(scale(1_000_000)),
        "initial_weight": scale("0.5"),
    },
    {
        "underlying": {
            "name": "Wrapped Ethereum",
            "symbol": "WETH",
            "decimals": 18,
            "price": scale(1200),
        },
        "mint_fee": scale("0.001"),
        "redeem_fee": scale("0.002"),
        "short_flow_memory": int(constants.OUTFLOW_MEMORY),
        "short_flow_threshold": int(scale(500)),
        "initial_weight": scale("0.25"),
    },
    {
        "underlying": {
            "name": "USD Coin",
            "symbol": "USDC",
            "decimals": 18,
            "price": scale(1),
        },
        "mint_fee": scale("0.0001"),
        "redeem_fee": scale("0.0005"),
        "short_flow_memory": int(constants.OUTFLOW_MEMORY),
        "short_flow_threshold": int(scale(1_000_000, 18)),
        "initial_weight": scale("0.25"),
    },
]


@with_gas_usage
@with_deployed(StaticPercentageFeeHandler)
def set_fees(static_percentage_fee_handler):
    deployer = get_deployer()
    for i, vault in enumerate(vaults):
        static_percentage_fee_handler.setVaultFees(
            GenericVault[i],
            vault["mint_fee"],
            vault["redeem_fee"],
            {"from": deployer},
        )


@with_gas_usage
@with_deployed(ReserveManager)
def register_vaults(reserve_manager):
    deployer = get_deployer()
    for i, vault_info in enumerate(vaults):
        vault = GenericVault[i]
        reserve_manager.registerVault(
            vault,
            vault_info["initial_weight"],
            vault_info["short_flow_memory"],
            vault_info["short_flow_threshold"],
            {"from": deployer, "allow_revert": True, "gas_limit": 1_000_000},
        )


@with_gas_usage
@with_deployed(MockPriceOracle)
def main(mock_price_oracle):
    deployer = get_deployer()
    for vault_info in vaults:
        decimals = vault_info["underlying"]["decimals"]

        name = vault_info["underlying"]["name"]
        symbol = vault_info["underlying"]["symbol"]
        token = deployer.deploy(
            Token,
            name,
            symbol,
            decimals,
            scale(10_000, decimals),
        )
        mock_price_oracle.setUSDPrice(
            token, vault_info["underlying"]["price"], {"from": deployer}
        )

        deployer.deploy(GenericVault, token, f"Vault {name}", f"gv{symbol}")
