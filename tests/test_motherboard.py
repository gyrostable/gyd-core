from typing import List
from pyparsing import Or
import pytest
from brownie.test.managers.runner import RevertContextManager as reverts
from tests.fixtures.mainnet_contracts import TokenAddresses

from tests.support import config_keys, error_codes
from tests.support.quantized_decimal import QuantizedDecimal as D
from tests.support.constants import BALANCER_POOL_IDS, address_from_pool_id
from tests.support.types import (
    MintAsset,
    Order,
    RedeemAsset,
    VaultToDeploy,
    VaultWithAmount,
)
from tests.support.utils import join_pool, scale


@pytest.fixture(scope="module", autouse=True)
def set_mock_oracle_prices(mock_price_oracle, usdc, usdc_vault, dai, dai_vault, admin):
    mock_price_oracle.setUSDPrice(usdc, scale(1), {"from": admin})
    mock_price_oracle.setUSDPrice(usdc_vault, scale(1), {"from": admin})
    mock_price_oracle.setUSDPrice(dai, scale(1), {"from": admin})
    mock_price_oracle.setUSDPrice(dai_vault, scale(1), {"from": admin})


@pytest.fixture(scope="module", autouse=True)
def set_fees(static_percentage_fee_handler, usdc_vault, dai_vault, admin):
    static_percentage_fee_handler.setVaultFees(usdc_vault, 0, 0, {"from": admin})
    static_percentage_fee_handler.setVaultFees(dai_vault, 0, 0, {"from": admin})


@pytest.fixture
def register_usdc_vault(reserve_manager, usdc_vault, admin):
    reserve_manager.registerVault(usdc_vault, scale(1), 0, 0, {"from": admin})


@pytest.fixture
def register_usdc_and_dai_vaults(reserve_manager, usdc_vault, dai_vault, admin):
    reserve_manager.registerVault(dai_vault, scale("0.6"), 0, 0, {"from": admin})
    reserve_manager.registerVault(usdc_vault, scale("0.4"), 0, 0, {"from": admin})


@pytest.mark.usefixtures("register_usdc_vault")
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


@pytest.mark.usefixtures("register_usdc_vault")
def test_mint_vault_underlying(
    motherboard, usdc, usdc_vault, alice, gyd_token, reserve
):
    usdc_amount = scale(10, usdc.decimals())
    usdc.approve(motherboard, usdc_amount, {"from": alice})
    mint_asset = MintAsset(
        inputToken=usdc, inputAmount=usdc_amount, destinationVault=usdc_vault
    )
    tx = motherboard.mint([mint_asset], 0, {"from": alice})
    gyd_minted = tx.return_value
    assert gyd_token.balanceOf(alice) == scale(10)
    assert gyd_minted == scale(10)
    assert usdc_vault.balanceOf(reserve) == usdc_amount


@pytest.mark.usefixtures("register_usdc_and_dai_vaults")
def test_mint_using_multiple_assets(
    motherboard, usdc, usdc_vault, dai, dai_vault, gyd_token, alice, reserve
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
    assert usdc_vault.balanceOf(reserve) == usdc_amount
    assert dai_vault.balanceOf(reserve) == dai_amount


@pytest.mark.usefixtures("register_usdc_vault")
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


@pytest.mark.usefixtures("register_usdc_vault")
def test_redeem_vault_underlying(
    motherboard, usdc, usdc_vault, alice, gyd_token, reserve
):
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
    assert usdc_vault.balanceOf(reserve) == 0


@pytest.mark.usefixtures("register_usdc_vault")
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


@pytest.mark.usefixtures("register_usdc_vault")
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


@pytest.mark.usefixtures("register_usdc_vault")
def test_mint_too_much_slippage(motherboard, usdc, usdc_vault, alice):
    usdc_amount = scale(10, usdc.decimals())
    usdc.approve(motherboard, usdc_amount, {"from": alice})
    mint_asset = MintAsset(
        inputToken=usdc, inputAmount=usdc_amount, destinationVault=usdc_vault
    )
    with reverts(error_codes.TOO_MUCH_SLIPPAGE):
        motherboard.mint([mint_asset], scale(10) + 1, {"from": alice})


@pytest.mark.usefixtures("register_usdc_vault")
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


@pytest.mark.usefixtures("register_usdc_vault")
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


@pytest.mark.usefixtures("register_usdc_vault")
def test_mint_vault_underlying_with_fees(
    motherboard,
    usdc,
    usdc_vault,
    alice,
    gyd_token,
    static_percentage_fee_handler,
    admin,
):
    usdc_amount = scale(10, usdc.decimals())
    usdc.approve(motherboard, usdc_amount, {"from": alice})
    mint_asset = MintAsset(
        inputToken=usdc, inputAmount=usdc_amount, destinationVault=usdc_vault
    )
    static_percentage_fee_handler.setVaultFees(
        usdc_vault, scale("0.1"), 0, {"from": admin}
    )
    tx = motherboard.mint([mint_asset], 0, {"from": alice})
    gyd_minted = tx.return_value
    assert gyd_token.balanceOf(alice) == scale(9)
    assert gyd_minted == scale(9)


@pytest.mark.usefixtures("register_usdc_vault")
def test_redeem_vault_underlying_with_fees(
    motherboard,
    usdc,
    usdc_vault,
    alice,
    gyd_token,
    static_percentage_fee_handler,
    admin,
    reserve,
):
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

    static_percentage_fee_handler.setVaultFees(
        usdc_vault, 0, scale("0.1"), {"from": admin}
    )
    tx = motherboard.redeem(scale(10), [redeem_asset], {"from": alice})
    output_amount = usdc_amount * D("0.9")
    assert tx.return_value == [output_amount]
    assert gyd_token.balanceOf(alice) == 0
    assert usdc.balanceOf(alice) == balance_before_redeem + output_amount
    assert usdc_vault.balanceOf(reserve) == usdc_amount - output_amount


@pytest.fixture
def make_bpt_mint_asset(mainnet_vaults, interface, alice, full_motherboard):
    def _make_mint_asset(pool_name):
        pool = address_from_pool_id(BALANCER_POOL_IDS[pool_name])
        vault = [v for v in mainnet_vaults if v.pool == pool][0]
        balance = interface.ERC20(pool).balanceOf(alice)
        interface.ERC20(pool).approve(full_motherboard, balance, {"from": alice})
        return MintAsset(pool, balance, vault.address)

    return _make_mint_asset


@pytest.fixture
def make_bpt_redeem_asset(mainnet_vaults):
    def _make_redeem_asset(pool_name, min_amount, ratio):
        pool = address_from_pool_id(BALANCER_POOL_IDS[pool_name])
        vault = [v for v in mainnet_vaults if v.pool == pool][0]
        return RedeemAsset(pool, min_amount, ratio, vault.address)

    return _make_redeem_asset


@pytest.mark.endToEnd
def test_simple_mint_bpt(
    full_motherboard,
    balancer_vault,
    alice,
    dai,
    weth,
    wbtc,
    usdc,
    make_bpt_mint_asset,
):
    amounts = [(weth.address, int(scale("0.01"))), (dai.address, int(scale(50)))]
    join_pool(alice, balancer_vault, BALANCER_POOL_IDS["WETH_DAI"], amounts)
    amounts = [
        (wbtc.address, int(scale("0.0003", 8))),
        (weth.address, int(scale("0.002"))),
    ]
    join_pool(alice, balancer_vault, BALANCER_POOL_IDS["WBTC_WETH"], amounts)

    amounts = [(weth.address, int(scale("0.01"))), (usdc.address, int(scale(35, 6)))]
    join_pool(alice, balancer_vault, BALANCER_POOL_IDS["WETH_USDC"], amounts)

    mint_assets = [
        make_bpt_mint_asset("WETH_DAI"),
        make_bpt_mint_asset("WBTC_WETH"),
        make_bpt_mint_asset("WETH_USDC"),
    ]

    amount, error = full_motherboard.dryMint(mint_assets, scale(60), {"from": alice})
    assert error == ""
    assert scale(60) <= amount <= scale(180)

    tx = full_motherboard.mint(mint_assets, scale(60), {"from": alice})
    # last transfer is the transfer from motherboard to user
    value = tx.events["Transfer"][-1]["value"]
    assert abs(value - amount) <= scale(10)


@pytest.mark.endToEnd
def test_simple_redeem_bpt(
    full_motherboard,
    balancer_vault,
    alice,
    dai,
    weth,
    wbtc,
    usdc,
    make_bpt_mint_asset,
    make_bpt_redeem_asset,
    mainnet_pamm,
    mainnet_reserve_manager,
    interface,
):
    print("starting test")

    amounts = [(weth.address, int(scale("0.01"))), (dai.address, int(scale(50)))]
    join_pool(alice, balancer_vault, BALANCER_POOL_IDS["WETH_DAI"], amounts)
    amounts = [
        (wbtc.address, int(scale("0.0003", 8))),
        (weth.address, int(scale("0.002"))),
    ]
    join_pool(alice, balancer_vault, BALANCER_POOL_IDS["WBTC_WETH"], amounts)

    amounts = [(weth.address, int(scale("0.01"))), (usdc.address, int(scale(35, 6)))]
    join_pool(alice, balancer_vault, BALANCER_POOL_IDS["WETH_USDC"], amounts)

    mint_assets = [
        make_bpt_mint_asset("WETH_DAI"),
        make_bpt_mint_asset("WBTC_WETH"),
        make_bpt_mint_asset("WETH_USDC"),
    ]

    print("minting with", mint_assets)

    tx = full_motherboard.mint(mint_assets, scale("60"), {"from": alice})
    value = tx.events["Transfer"][-1]["value"]

    print(f"minted {value} GYD")

    redeem_assets = [
        make_bpt_redeem_asset("WETH_DAI", scale("0.05"), scale("0.5")),
        make_bpt_redeem_asset("WETH_USDC", scale("0.05"), scale("0.4")),
        make_bpt_redeem_asset("WBTC_WETH", scale("0.0001"), scale("0.1")),
    ]

    gyro_to_redeem = value // 2

    reserve_usd_value, vaults = mainnet_reserve_manager.getReserveState()
    print(
        "pamm value",
        mainnet_pamm.computeRedeemAmount(gyro_to_redeem, reserve_usd_value),
    )
    print("vaults", vaults)

    print("redeeming with", redeem_assets)

    output_amounts, err = full_motherboard.dryRedeem(gyro_to_redeem, redeem_assets)
    print("output amounts", output_amounts)
    assert err == ""
    assert output_amounts[0] >= redeem_assets[0].minOutputAmount
    assert output_amounts[1] >= redeem_assets[1].minOutputAmount

    tokens = [interface.ERC20(a.outputToken) for a in redeem_assets]

    previous_balances = [t.balanceOf(alice) for t in tokens]
    tx = full_motherboard.redeem(gyro_to_redeem, redeem_assets, {"from": alice})
    new_balances = [t.balanceOf(alice) for t in tokens]
    for pb, nb, asset in zip(previous_balances, new_balances, redeem_assets):
        assert nb >= pb + asset.minOutputAmount
