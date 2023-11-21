
# One-off deployment for testing mostly.

from scripts.utils import with_gas_usage, get_deployer, make_tx_params
from tests.fixtures.mainnet_contracts import TokenAddresses
from tests.support import constants
from tests.support.types import DisconnectedGenericVaultToDeploy, VaultToDeploy, VaultType

from brownie import GenericVault

vault_to_deploy = DisconnectedGenericVaultToDeploy(
    underlying=TokenAddresses.aDAIv2,
    name="TEST Gyroscope Wrapped aDAI",
    symbol="TV-aDAIv2",
)

@with_gas_usage
def main():
    deployer = get_deployer()
    deployer.deploy(
        GenericVault,
        deployer,
        vault_to_deploy.underlying,
        vault_to_deploy.name,
        vault_to_deploy.symbol,
        **make_tx_params(),
    )
