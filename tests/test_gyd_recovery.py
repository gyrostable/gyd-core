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
def register_dai_vault_module(reserve_manager, dai_vault, admin):
    reserve_manager.registerVault(dai_vault, scale(1), 0, 0, {"from": admin})


@pytest.fixture(scope="module")
def gyd_alice(motherboard, dai, dai_vault, alice, register_dai_vault_module, set_mock_oracle_prices_usdc_dai, set_fees_usdc_dai, gyro_config):
    """Puts alice's DAI into GYD. Alice will hold 10 GYD afterwards."""
    dai_amount = scale(5, dai.decimals())
    dai.approve(motherboard, dai_amount, {"from": alice})
    mint_asset = MintAsset(
        inputToken=dai, inputAmount=dai_amount, destinationVault=dai_vault
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
    alice, gyd_recovery, gyd_token, mock_price_oracle, dai, dai_vault, admin
):
    gyd_amount = scale(2)
    gyd_token.approve(gyd_recovery, gyd_amount, {"from": alice})
    gyd_recovery.deposit(gyd_amount, {"from": alice})

    tx = gyd_recovery.initiateWithdrawal(10, {"from": alice})
    withdrawal_id = tx.events["WithdrawalQueued"]["id"]

    mock_price_oracle.setUSDPrice(dai, scale(D("0.6")), {"from": admin})
    mock_price_oracle.setUSDPrice(dai_vault, scale(D("0.6")), {"from": admin})

    assert gyd_recovery.shouldRun() == True
    start_gyd_supply = gyd_token.totalSupply()
    tx = gyd_recovery.checkAndRun()
    end_gyd_supply = gyd_token.totalSupply()
    assert start_gyd_supply - end_gyd_supply == gyd_amount

    assert tx.events['RecoveryExecuted']['tokensBurned'] == gyd_amount
    assert tx.events['RecoveryExecuted']['isFullBurn']
    assert tx.events['RecoveryExecuted']['newAdjustmentFactor'] == scale(1)

    with reverts(revert_msg="not enough to withdraw"):
        gyd_recovery.initiateWithdrawal(10, {"from": alice})
