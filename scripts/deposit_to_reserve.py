from brownie import accounts, interface
from scripts.utils import make_tx_params  # type: ignore

from tests.support.utils import format_to_bytes  # type: ignore

GYRO_CONFIG_ADDRESS = "0x3c00e4663be7262E50251380EBE5fE4A17e68B51"


def main():
    account = accounts.load("gyro-deployer")
    gyro_config = interface.IGyroConfig(GYRO_CONFIG_ADDRESS)
    vault_registry = gyro_config.getAddress(
        format_to_bytes("VAULT_REGISTRY_ADDRESS", 32)
    )
    reserve = interface.IReserve(
        gyro_config.getAddress(format_to_bytes("RESERVE_ADDRESS", 32))
    )
    vaults = interface.IVaultRegistry(vault_registry).listVaults()
    balances = [interface.ERC20(vault).balanceOf(account) for vault in vaults]
    params = {"from": account, **make_tx_params()}
    for vault, balance in list(zip(vaults, balances))[3:]:
        print(f"{vault}: {balance}")
        amount_to_deposit = balance // 3
        if interface.ERC20(vault).allowance(account, reserve) == 0:
            interface.ERC20(vault).approve(reserve, 2**256 - 1, params)
        reserve.depositToken(vault, amount_to_deposit, params)
