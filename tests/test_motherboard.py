import pytest
from brownie.test.managers.runner import RevertContextManager as reverts

from tests.support import error_codes
from tests.support.constants import BALANCER_POOL_IDS
from tests.support.types import MintAsset, RedeemAsset
from tests.support.utils import join_pool, scale


@pytest.fixture(scope="module")
def set_mock_oracle_prices(mock_price_oracle, usdc, usdc_vault, dai, dai_vault):
    mock_price_oracle.setUSDPrice(usdc, scale(1))
    mock_price_oracle.setUSDPrice(usdc_vault, scale(1))
    mock_price_oracle.setUSDPrice(dai, scale(1))
    mock_price_oracle.setUSDPrice(dai_vault, scale(1))


@pytest.fixture
def register_usdc_vault(vault_registry, usdc_vault, admin):
    vault_registry.registerVault(usdc_vault, scale(1), {"from": admin})


@pytest.fixture
def register_usdc_and_dai_vaults(vault_registry, usdc_vault, dai_vault, admin):
    vault_registry.registerVault(dai_vault, scale("0.6"), {"from": admin})
    vault_registry.registerVault(usdc_vault, scale("0.4"), {"from": admin})


@pytest.mark.usefixtures("set_mock_oracle_prices", "register_usdc_vault")
def test_dry_mint_vault_underlying(motherboard, usdc, usdc_vault, alice):
    decimals = usdc.decimals()
    usdc_amount = scale(10, decimals)
    usdc.approve(motherboard, usdc_amount, {"from": alice})
    mint_asset = MintAsset(
        inputToken=usdc, inputAmount=usdc_amount, destinationVault=usdc_vault
    )
    gyd_minted, err = motherboard.dryMint([mint_asset], 0, {"from": alice})
    assert err == ""
    assert gyd_minted == scale(10)


@pytest.mark.usefixtures("set_mock_oracle_prices", "register_usdc_vault")
def test_mint_vault_underlying(motherboard, usdc, usdc_vault, alice, gyd_token):
    usdc_amount = scale(10, usdc.decimals())
    usdc.approve(motherboard, usdc_amount, {"from": alice})
    mint_asset = MintAsset(
        inputToken=usdc, inputAmount=usdc_amount, destinationVault=usdc_vault
    )
    tx = motherboard.mint([mint_asset], 0, {"from": alice})
    gyd_minted = tx.return_value
    assert gyd_token.balanceOf(alice) == scale(10)
    assert gyd_minted == scale(10)


@pytest.mark.usefixtures("set_mock_oracle_prices", "register_usdc_and_dai_vaults")
def test_mint_using_multiple_assets(
    motherboard, usdc, usdc_vault, dai, dai_vault, gyd_token, alice
):
    usdc_amount = scale(10, usdc.decimals())
    usdc.approve(motherboard, usdc_amount, {"from": alice})
    dai_amount = scale(5, dai.decimals())
    dai.approve(motherboard, dai_amount, {"from": alice})
    mint_assets = [
        MintAsset(
            inputToken=usdc, inputAmount=usdc_amount, destinationVault=usdc_vault
        ),
        MintAsset(inputToken=dai, inputAmount=dai_amount, destinationVault=dai_vault),
    ]
    tx = motherboard.mint(mint_assets, 0, {"from": alice})
    gyd_minted = tx.return_value
    assert gyd_token.balanceOf(alice) == scale(15)
    assert gyd_minted == scale(15)


@pytest.mark.usefixtures("set_mock_oracle_prices", "register_usdc_vault")
def test_dry_redeem_vault_underlying(motherboard, usdc, usdc_vault, alice):
    usdc_amount = scale(10, usdc.decimals())
    usdc.approve(motherboard, usdc_amount, {"from": alice})

    mint_asset = MintAsset(
        inputToken=usdc, inputAmount=usdc_amount, destinationVault=usdc_vault
    )
    motherboard.mint([mint_asset], 0, {"from": alice})

    redeem_asset = RedeemAsset(
        outputToken=usdc, minOutputAmount=0, originVault=usdc_vault, valueRatio=scale(1)
    )
    output_amounts, err = motherboard.dryRedeem(scale(10), [redeem_asset])
    assert err == ""
    assert output_amounts == [scale(10, 6)]


@pytest.mark.usefixtures("set_mock_oracle_prices", "register_usdc_vault")
def test_redeem_vault_underlying(motherboard, usdc, usdc_vault, alice, gyd_token):
    usdc_amount = scale(10, usdc.decimals())
    usdc.approve(motherboard, usdc_amount, {"from": alice})

    mint_asset = MintAsset(
        inputToken=usdc, inputAmount=usdc_amount, destinationVault=usdc_vault
    )
    motherboard.mint([mint_asset], 0, {"from": alice})

    redeem_asset = RedeemAsset(
        outputToken=usdc, minOutputAmount=0, originVault=usdc_vault, valueRatio=scale(1)
    )
    balance_before_redeem = usdc.balanceOf(alice)
    tx = motherboard.redeem(scale(10), [redeem_asset], {"from": alice})
    assert tx.return_value == [usdc_amount]
    assert gyd_token.balanceOf(alice) == 0
    assert usdc.balanceOf(alice) == balance_before_redeem + usdc_amount


@pytest.mark.usefixtures("set_mock_oracle_prices", "register_usdc_vault")
def test_mint_vault_token(motherboard, usdc, usdc_vault, alice, gyd_token):
    usdc_amount = scale(10, usdc.decimals())
    usdc.approve(usdc_vault, usdc_amount, {"from": alice})
    usdc_vault.deposit(usdc_amount, 0, {"from": alice})
    assert usdc_vault.balanceOf(alice) == usdc_amount
    usdc_vault.approve(motherboard, usdc_amount, {"from": alice})
    mint_asset = MintAsset(
        inputToken=usdc_vault, inputAmount=usdc_amount, destinationVault=usdc_vault
    )
    tx = motherboard.mint([mint_asset], 0, {"from": alice})
    assert gyd_token.balanceOf(alice) == scale(10)
    assert tx.return_value == scale(10)
    assert usdc_vault.balanceOf(alice) == 0


@pytest.mark.usefixtures("set_mock_oracle_prices", "register_usdc_vault")
def test_redeem_vault_token(motherboard, usdc, usdc_vault, alice, gyd_token):
    usdc_amount = scale(10, usdc.decimals())
    usdc.approve(usdc_vault, usdc_amount, {"from": alice})
    usdc_vault.deposit(usdc_amount, 0, {"from": alice})
    usdc_vault.approve(motherboard, usdc_amount, {"from": alice})
    mint_asset = MintAsset(
        inputToken=usdc_vault, inputAmount=usdc_amount, destinationVault=usdc_vault
    )
    tx = motherboard.mint([mint_asset], 0, {"from": alice})

    redeem_asset = RedeemAsset(
        outputToken=usdc_vault,
        minOutputAmount=0,
        originVault=usdc_vault,
        valueRatio=scale(1),
    )
    tx = motherboard.redeem(scale(10), [redeem_asset], {"from": alice})
    assert tx.return_value == [usdc_amount]
    assert gyd_token.balanceOf(alice) == 0
    assert usdc_vault.balanceOf(alice) == usdc_amount


@pytest.mark.usefixtures("set_mock_oracle_prices", "register_usdc_vault")
def test_mint_too_much_slippage(motherboard, usdc, usdc_vault, alice):
    usdc_amount = scale(10, usdc.decimals())
    usdc.approve(motherboard, usdc_amount, {"from": alice})
    mint_asset = MintAsset(
        inputToken=usdc, inputAmount=usdc_amount, destinationVault=usdc_vault
    )
    with reverts(error_codes.TOO_MUCH_SLIPPAGE):
        motherboard.mint([mint_asset], scale(10) + 1, {"from": alice})


@pytest.mark.usefixtures("set_mock_oracle_prices", "register_usdc_vault")
def test_redeem_too_much_slippage(motherboard, usdc, usdc_vault, alice):
    usdc_amount = scale(10, usdc.decimals())
    usdc.approve(motherboard, usdc_amount, {"from": alice})
    mint_asset = MintAsset(
        inputToken=usdc, inputAmount=usdc_amount, destinationVault=usdc_vault
    )
    motherboard.mint([mint_asset], 0, {"from": alice})
    redeem_asset = RedeemAsset(
        outputToken=usdc,
        minOutputAmount=usdc_amount + 1,
        originVault=usdc_vault,
        valueRatio=scale(1),
    )
    with reverts(error_codes.TOO_MUCH_SLIPPAGE):
        motherboard.redeem(scale(10), [redeem_asset], {"from": alice})


@pytest.mark.usefixtures("set_mock_oracle_prices", "register_usdc_vault")
@pytest.mark.parametrize("value_ratio", ["0.5", "1.5"])
def test_redeem_invalid_ratio(motherboard, usdc, usdc_vault, alice, value_ratio):
    usdc_amount = scale(10, usdc.decimals())
    usdc.approve(motherboard, usdc_amount, {"from": alice})
    mint_asset = MintAsset(
        inputToken=usdc, inputAmount=usdc_amount, destinationVault=usdc_vault
    )
    motherboard.mint([mint_asset], 0, {"from": alice})
    redeem_asset = RedeemAsset(
        outputToken=usdc,
        minOutputAmount=usdc_amount,
        originVault=usdc_vault,
        valueRatio=scale(value_ratio),
    )
    with reverts(error_codes.INVALID_ARGUMENT):
        motherboard.redeem(scale(10), [redeem_asset], {"from": alice})


@pytest.mark.mainnetFork
def test_simple_mint_bpt(motherboard, balancer_vault, alice, dai, weth, wbtc):
    amounts = [(weth.address, int(scale("0.01"))), (dai.address, int(scale(50)))]
    join_pool(alice, balancer_vault, BALANCER_POOL_IDS["WETH_DAI"], amounts)
    amounts = [
        (wbtc.address, int(scale("0.005", 8))),
        (weth.address, int(scale("0.05"))),
    ]
    join_pool(alice, balancer_vault, BALANCER_POOL_IDS["WBTC_WETH"], amounts)
