from brownie import GenericVault, Token, StaticPercentageFeeHandler, ReserveManager, MockPriceOracle, GovernanceProxy  # type: ignore
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
@with_deployed(GovernanceProxy)
def set_fees(governance_proxy, static_percentage_fee_handler):
    deployer = get_deployer()
    for i, vault in enumerate(vaults):
        governance_proxy.executeCall(
            static_percentage_fee_handler,
            static_percentage_fee_handler.setVaultFees.encode_input(
                GenericVault[i], vault["mint_fee"], vault["redeem_fee"]
            ),
            {"from": deployer},
        )


@with_gas_usage
@with_deployed(ReserveManager)
@with_deployed(GovernanceProxy)
def register_vaults(governance_proxy, reserve_manager):
    deployer = get_deployer()
    for i, vault_info in enumerate(vaults):
        vault = GenericVault[i]
        governance_proxy.executeCall(
            reserve_manager,
            reserve_manager.registerVault.encode_input(
                vault,
                vault_info["initial_weight"],
                vault_info["short_flow_memory"],
                vault_info["short_flow_threshold"],
            ),
            {"from": deployer, "allow_revert": True, "gas_limit": 1_000_000},
        )


@with_gas_usage
@with_deployed(MockPriceOracle)
@with_deployed(GovernanceProxy)
def main(governance_proxy, mock_price_oracle):
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

        deployer.deploy(
            GenericVault, governance_proxy, token, f"Vault {name}", f"gv{symbol}"
        )
