from brownie import ZERO_ADDRESS
from tests.fixtures.mainnet_contracts import TokenAddresses
from tests.support import constants
from tests.support.types import GenericVaultToDeploy, VaultToDeploy, VaultType
from tests.support.utils import bp, scale


vaults = {
    1: [
        VaultToDeploy(
            pool_id=constants.BALANCER_POOL_IDS[1]["USDP_GUSD"],
            vault_type=VaultType.BALANCER_ECLP,
            name="Gyroscope ECLP USDP/GUSD Vault",
            symbol="V-ECLP-USDP-GUSD",
            initial_weight=int(scale("0.08")),
            short_flow_memory=int(constants.SHORT_FLOW_MEMORY),
            short_flow_threshold=4_400_000,  # USD value
            mint_fee=0,
            redeem_fee=bp(5),
        ),
        VaultToDeploy(
            pool_id=constants.BALANCER_POOL_IDS[1]["LUSD_CRVUSD"],
            vault_type=VaultType.BALANCER_ECLP,
            name="Gyroscope ECLP LUSD/crvUSD Vault",
            symbol="V-ECLP-LUSD-crvUSD",
            initial_weight=int(scale("0.1")),
            short_flow_memory=int(constants.SHORT_FLOW_MEMORY),
            short_flow_threshold=5_500_000,  # USD value
            mint_fee=bp(1),
            redeem_fee=bp(5),
        ),
        GenericVaultToDeploy(
            underlying=TokenAddresses.fUSDC,
            name="Gyroscope fUSDC Vault",
            symbol="V-fUSDC",
            initial_weight=int(scale("0.16")),
            short_flow_memory=int(constants.SHORT_FLOW_MEMORY),
            short_flow_threshold=8_700_000,  # USD value
            mint_fee=0,
            redeem_fee=bp(2),
        ),
        GenericVaultToDeploy(
            underlying=TokenAddresses.sDAI,
            name="Gyroscope sDAI Vault",
            symbol="V-sDAI",
            initial_weight=int(scale("0.56")),
            short_flow_memory=int(constants.SHORT_FLOW_MEMORY),
            short_flow_threshold=30_000_000,  # USD value
            mint_fee=0,
            redeem_fee=bp(3),
        ),
        GenericVaultToDeploy(
            underlying=TokenAddresses.aUSDT,
            name="Gyroscope aUSDT Vault",
            symbol="V-aUSDT",
            initial_weight=int(scale("0.1")),
            short_flow_memory=int(constants.SHORT_FLOW_MEMORY),
            short_flow_threshold=5_500_000,  # USD value
            mint_fee=0,
            redeem_fee=bp(3),
        ),
    ],
    137: [
        VaultToDeploy(
            pool_id=constants.BALANCER_POOL_IDS["WETH_DAI"],
            vault_type=VaultType.BALANCER_CPMM,
            name="Balancer CPMM WETH-DAI",
            symbol="BAL-CPMM-WETH-DAI",
            initial_weight=int(scale("0.5")),
            short_flow_memory=int(constants.OUTFLOW_MEMORY),
            short_flow_threshold=int(scale(1_000_000)),
            mint_fee=int(scale("0.005")),
            redeem_fee=int(scale("0.01")),
        ),
        VaultToDeploy(
            pool_id=constants.BALANCER_POOL_IDS["WETH_USDC"],
            vault_type=VaultType.BALANCER_CPMM,
            name="Balancer CPMM WETH-USDC",
            symbol="BAL-CPMM-WETH-USDC",
            initial_weight=int(scale("0.4")),
            short_flow_memory=int(constants.OUTFLOW_MEMORY),
            short_flow_threshold=int(scale(1_000_000)),
            mint_fee=int(scale("0.002")),
            redeem_fee=int(scale("0.005")),
        ),
        VaultToDeploy(
            pool_id=constants.BALANCER_POOL_IDS["WBTC_WETH"],
            vault_type=VaultType.BALANCER_CPMM,
            name="Balancer CPMM WBTC-WETH",
            symbol="BAL-CPMM-WBTC-WETH",
            initial_weight=int(scale("0.1")),
            short_flow_memory=int(constants.OUTFLOW_MEMORY),
            short_flow_threshold=int(scale(1_000_000)),
            mint_fee=int(scale("0.004")),
            redeem_fee=int(scale("0.015")),
        ),
    ],
}

vaults[1337] = vaults[1]
