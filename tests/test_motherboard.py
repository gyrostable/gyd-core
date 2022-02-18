import pytest
from tests.support.types import MintAsset
from tests.support.utils import format_to_bytes, scale


@pytest.fixture(scope="module")
def set_mock_oracle_prices(mock_price_oracle, usdc, usdc_vault):
    mock_price_oracle.setUSDPrice(usdc, scale(1))
    mock_price_oracle.setUSDPrice(usdc_vault, scale(1))


@pytest.mark.usefixtures("set_mock_oracle_prices")
def test_mint_vault_underlying(
    motherboard, usdc, usdc_vault, alice, vault_registry, admin
):
    vault_registry.registerVault(
        usdc_vault, scale(1), format_to_bytes("0", 32), {"from": admin}
    )
    decimals = usdc.decimals()
    usdc_amount = scale(10, decimals)
    usdc.approve(motherboard, usdc_amount, {"from": alice})
    mint_asset = MintAsset(
        inputToken=usdc, inputAmount=usdc_amount, destinationVault=usdc_vault
    )
    tx = motherboard.mint([mint_asset], 0, {"from": alice})
    gyd_minted = tx.return_value
    assert gyd_minted == scale(10)
