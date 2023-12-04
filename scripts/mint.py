from brownie import ReserveManager, Motherboard, interface  # type: ignore
from scripts.utils import get_deployer, make_tx_params

from tests.support.types import VaultInfo, MintAsset

AMOUNT_TO_MINT = 100


def main():
    amount = AMOUNT_TO_MINT
    deployer = get_deployer()

    reserve_manager = ReserveManager.at("0x2519A729535470830D345b78109818F94C1c2869")
    motherboard = Motherboard.at("0x8De76bF863E0A571be7165d9c85A1116c0fFf393")

    reserve_state = reserve_manager.getReserveState()
    vaults = [VaultInfo.from_tuple(v) for v in reserve_state[1]]
    mint_assets = []
    for vault in vaults:
        input_amount = (
            vault.target_weight * amount * 10**vault.decimals // vault.price
        )
        underlying = interface.ERC20(vault.underlying)
        if underlying.allowance(deployer, motherboard) < input_amount:
            underlying.approve(
                motherboard, 2**256 - 1, {"from": deployer, **make_tx_params()}
            )
        print(
            vault.vault,
            input_amount,
            interface.ERC20(vault.underlying).balanceOf(deployer) > input_amount,
        )
        mint_asset = MintAsset(
            inputToken=vault.underlying,
            inputAmount=input_amount,
            destinationVault=vault.vault,
        )
        mint_assets.append(mint_asset)

    print(mint_assets)

    print(motherboard.dryMint(mint_assets, 0))
    # motherboard.mint(mint_assets, 0, {"from": deployer, **make_tx_params()})
