import pytest

from brownie.test.managers.runner import RevertContextManager as reverts
from brownie import chain

from tests.support.types import MintAsset
from tests.support.utils import scale

from tests.support import config_keys, constants

from decimal import Decimal as D


@pytest.fixture(scope="module", autouse=True)
def my_init(set_mock_oracle_prices_usdc_dai, set_fees_usdc_dai):
    pass


@pytest.fixture(scope="module")
def register_usdc_vault_module(reserve_manager, usdc_vault, admin):
    reserve_manager.registerVault(usdc_vault, scale(1), 0, 0, {"from": admin})


@pytest.fixture(scope="module")
def gyd_alice(
    motherboard,
    usdc,
    usdc_vault,
    alice,
    register_usdc_vault_module,
    set_mock_oracle_prices_usdc_dai,
    set_fees_usdc_dai,
    gyro_config,
):
    """Puts alice's USDC into GYD. Alice will hold 10 GYD afterwards."""
    usdc_amount = scale(10, usdc.decimals())
    usdc.approve(motherboard, usdc_amount, {"from": alice})
    mint_asset = MintAsset(
        inputToken=usdc, inputAmount=usdc_amount, destinationVault=usdc_vault
    )
    motherboard.mint([mint_asset], 0, {"from": alice})


@pytest.mark.usefixtures("gyd_alice")
def test_deposit(alice, gyd_recovery, gyd_token):
    # Simple "dummy" test
    gyd_amount = scale(2)
    gyd_token.approve(gyd_recovery, gyd_amount, {"from": alice})
    gyd_recovery.deposit(gyd_amount, {"from": alice})
    assert gyd_recovery.balanceOf(alice) == gyd_amount


@pytest.mark.usefixtures("gyd_alice")
def test_initiate_withdrawal(gyd_token, gyd_recovery, alice):
    gyd_amount = scale(2)
    gyd_token.approve(gyd_recovery, gyd_amount, {"from": alice})
    gyd_recovery.deposit(gyd_amount, {"from": alice})

    start_bal = gyd_recovery.balanceOf(alice)
    with reverts(revert_msg="not enough to withdraw"):
        gyd_recovery.initiateWithdrawal(start_bal + 10, {"from": alice})

    gyd_recovery.initiateWithdrawal(10, {"from": alice})
    end_bal = gyd_recovery.balanceOf(alice)
    assert end_bal == start_bal - 10
    assert gyd_recovery.totalBalanceOf(alice) == end_bal + 10


@pytest.mark.usefixtures("gyd_alice")
def test_withdrawal(alice, gyd_recovery, gyd_token):
    gyd_amount = scale(2)
    gyd_token.approve(gyd_recovery, gyd_amount, {"from": alice})
    gyd_recovery.deposit(gyd_amount, {"from": alice})

    tx = gyd_recovery.initiateWithdrawal(10, {"from": alice})
    withdrawal_id = tx.events["WithdrawalQueued"]["id"]
    assert tx.events["WithdrawalQueued"]["to"] == alice

    with reverts(revert_msg="matching withdrawal does not exist"):
        gyd_recovery.withdraw(10, {"from": alice})

    with reverts(revert_msg="not yet withdrawable"):
        gyd_recovery.withdraw(withdrawal_id, {"from": alice})

    chain.sleep(constants.GYD_RECOVERY_WITHDRAWAL_WAIT_DURATION)
    chain.mine()

    start_bal = gyd_token.balanceOf(alice)
    assert gyd_token.balanceOf(gyd_recovery) == scale(2)
    gyd_recovery.withdraw(withdrawal_id, {"from": alice})
    assert gyd_token.balanceOf(alice) - start_bal == 10
    assert gyd_token.balanceOf(gyd_recovery) == scale(2) - 10
    assert gyd_recovery.totalBalanceOf(alice) == scale(2) - 10
    assert gyd_recovery.balanceOf(alice) == scale(2) - 10


@pytest.mark.usefixtures("gyd_alice")
def test_full_burn(
    alice, gyd_recovery, gyd_token, mock_price_oracle, usdc, usdc_vault, admin
):
    gyd_amount = scale(2)
    gyd_token.approve(gyd_recovery, gyd_amount, {"from": alice})
    gyd_recovery.deposit(gyd_amount, {"from": alice})

    tx = gyd_recovery.initiateWithdrawal(10, {"from": alice})
    withdrawal_id = tx.events["WithdrawalQueued"]["id"]

    mock_price_oracle.setUSDPrice(usdc, scale(D("0.6")), {"from": admin})
    mock_price_oracle.setUSDPrice(usdc_vault, scale(D("0.6")), {"from": admin})

    assert gyd_recovery.shouldRun() == True
    start_gyd_supply = gyd_token.totalSupply()
    gyd_recovery.checkAndRun()
    end_gyd_supply = gyd_token.totalSupply()
    assert start_gyd_supply - end_gyd_supply == gyd_amount

    with reverts(revert_msg="not enough to withdraw"):
        gyd_recovery.initiateWithdrawal(10, {"from": alice})
