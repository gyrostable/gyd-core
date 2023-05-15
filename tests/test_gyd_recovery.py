import pytest

from brownie.test.managers.runner import RevertContextManager as reverts
from brownie import chain, interface  # type: ignore

from tests.support.types import MintAsset
from tests.support.utils import scale

from tests.support import config_keys, constants

from tests.support.quantized_decimal import QuantizedDecimal as D


MINING_TOTAL_AMOUNT = scale(100)
MINING_TIME = 365 * 86400


@pytest.fixture(scope="module", autouse=True)
def my_init(set_mock_oracle_prices_usdc_dai, set_fees_usdc_dai):
    pass


@pytest.fixture(scope="module")
def register_dai_vault_module(reserve_manager, dai_vault, admin):
    reserve_manager.registerVault(dai_vault, scale(1), 0, 0, {"from": admin})


def mint_gyd_from_dai(dai, dai_vault, motherboard, account, amount):
    """amount unscaled"""
    dai_amount = scale(amount, dai.decimals())
    dai.approve(motherboard, dai_amount, {"from": account})
    mint_asset = MintAsset(
        inputToken=dai, inputAmount=dai_amount, destinationVault=dai_vault
    )
    motherboard.mint([mint_asset], 0, {"from": account})


@pytest.fixture(scope="module")
def gyd_alice(
    motherboard,
    dai,
    dai_vault,
    alice,
    register_dai_vault_module,
    set_mock_oracle_prices_usdc_dai,
    set_fees_usdc_dai,
    gyro_config,
):
    return mint_gyd_from_dai(dai, dai_vault, motherboard, alice, 10)


@pytest.fixture(scope="module")
def gyd_bob(
    motherboard,
    dai,
    dai_vault,
    bob,
    register_dai_vault_module,
    set_mock_oracle_prices_usdc_dai,
    set_fees_usdc_dai,
    gyro_config,
):
    return mint_gyd_from_dai(dai, dai_vault, motherboard, bob, 10)


@pytest.fixture(scope="module")
def gyd_recovery_mining(gyd_recovery, admin):
    reward_token = interface.IERC20(gyd_recovery.rewardToken())
    reward_token.approve(gyd_recovery, MINING_TOTAL_AMOUNT, {"from": admin})
    gyd_recovery.startMining(
        admin, MINING_TOTAL_AMOUNT, chain[-1].timestamp + MINING_TIME, {"from": admin}  # type: ignore
    )


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

    assert gyd_recovery.shouldRun() == False

    mock_price_oracle.setUSDPrice(dai, scale(D("0.6")), {"from": admin})
    mock_price_oracle.setUSDPrice(dai_vault, scale(D("0.6")), {"from": admin})

    assert gyd_recovery.shouldRun() == True
    start_gyd_supply = gyd_token.totalSupply()
    tx = gyd_recovery.checkAndRun()
    end_gyd_supply = gyd_token.totalSupply()
    assert start_gyd_supply - end_gyd_supply == gyd_amount

    assert tx.events["RecoveryExecuted"]["tokensBurned"] == gyd_amount
    assert tx.events["RecoveryExecuted"]["isFullBurn"]
    assert tx.events["RecoveryExecuted"]["newAdjustmentFactor"] == scale(1)

    with reverts(revert_msg="not enough to withdraw"):
        gyd_recovery.initiateWithdrawal(10, {"from": alice})
    assert gyd_recovery.balanceOf(alice) == 0
    assert gyd_recovery.totalBalanceOf(alice) == 0
    assert gyd_token.balanceOf(gyd_recovery) == 0

    chain.sleep(constants.GYD_RECOVERY_WITHDRAWAL_WAIT_DURATION)
    chain.mine()

    start_bal = gyd_token.balanceOf(alice)
    gyd_recovery.withdraw(withdrawal_id, {"from": alice})
    end_bal = gyd_token.balanceOf(alice)
    assert start_bal == end_bal


@pytest.mark.usefixtures("gyd_alice")
def test_partial_burn(
    alice, gyd_recovery, gyd_token, mock_price_oracle, dai, dai_vault, admin
):
    gyd_amount = scale(8)
    gyd_token.approve(gyd_recovery, gyd_amount, {"from": alice})
    gyd_recovery.deposit(gyd_amount, {"from": alice})

    start_gyd_supply = gyd_token.totalSupply()
    assert start_gyd_supply == scale(10)

    tx = gyd_recovery.initiateWithdrawal(scale(1), {"from": alice})
    withdrawal_id = tx.events["WithdrawalQueued"]["id"]

    mock_price_oracle.setUSDPrice(dai, scale(D("0.75")), {"from": admin})
    mock_price_oracle.setUSDPrice(dai_vault, scale(D("0.75")), {"from": admin})

    burn_amount = scale(D("2.5"))
    assert gyd_recovery.shouldRun() == True
    gyd_recovery.checkAndRun()
    end_gyd_supply = gyd_token.totalSupply()
    assert start_gyd_supply - end_gyd_supply == burn_amount

    assert gyd_token.balanceOf(gyd_recovery) == scale(8) - burn_amount
    assert gyd_recovery.totalBalanceOf(alice) == scale(8) - burn_amount

    adjustment_factor = scale(1) * (scale(8) - burn_amount) / scale(8)
    assert gyd_recovery.adjustedAmountToAmount(scale(1)) == adjustment_factor
    assert gyd_recovery.balanceOf(alice) == 7 * adjustment_factor

    chain.sleep(constants.GYD_RECOVERY_WITHDRAWAL_WAIT_DURATION)
    chain.mine()

    start_bal = gyd_token.balanceOf(alice)
    gyd_recovery.withdraw(withdrawal_id, {"from": alice})
    end_bal = gyd_token.balanceOf(alice)
    assert end_bal - start_bal == adjustment_factor


@pytest.mark.usefixtures("gyd_alice")
def test_multiple_burns(
    alice, gyd_recovery, gyd_token, mock_price_oracle, dai, dai_vault, admin
):
    gyd_amount = scale(8)
    gyd_token.approve(gyd_recovery, gyd_amount, {"from": alice})
    gyd_recovery.deposit(gyd_amount, {"from": alice})

    mock_price_oracle.setUSDPrice(dai, scale(D("0.75")), {"from": admin})
    mock_price_oracle.setUSDPrice(dai_vault, scale(D("0.75")), {"from": admin})

    burn_amount = D("2.5")
    adjustment_factor = D(1) * (D(8) - burn_amount) / D(8)
    gyd_recovery.checkAndRun()
    gyd_amount_2 = scale(1)
    gyd_token.approve(gyd_recovery, gyd_amount_2, {"from": alice})
    gyd_recovery.deposit(gyd_amount_2, {"from": alice})

    assert gyd_recovery.adjustmentFactor() == scale(adjustment_factor)
    new_bal_adjusted = D(8) + D(1) / adjustment_factor
    new_bal = new_bal_adjusted * adjustment_factor
    assert gyd_recovery.balanceAdjustedOf(alice) == scale(new_bal_adjusted)
    assert gyd_recovery.balanceOf(alice) == scale(new_bal)

    # check trigger condition
    mock_price_oracle.setUSDPrice(dai, scale(D("0.61")), {"from": admin})
    mock_price_oracle.setUSDPrice(dai_vault, scale(D("0.61")), {"from": admin})
    assert gyd_recovery.shouldRun() == False

    mock_price_oracle.setUSDPrice(dai, scale(D("0.60")), {"from": admin})
    mock_price_oracle.setUSDPrice(dai_vault, scale(D("0.60")), {"from": admin})
    assert gyd_recovery.shouldRun() == False

    # perform another burn
    mock_price_oracle.setUSDPrice(dai, scale(D("0.58")), {"from": admin})
    mock_price_oracle.setUSDPrice(dai_vault, scale(D("0.58")), {"from": admin})
    assert gyd_recovery.shouldRun() == True

    target_gyd_supply = D("0.58") * D(10)  # / constants.GYD_RECOVERY_TARGET_CR
    start_gyd_supply = gyd_token.totalSupply()
    burn_amount_2 = start_gyd_supply - scale(target_gyd_supply)

    gyd_recovery.checkAndRun()
    end_gyd_supply = gyd_token.totalSupply()

    assert start_gyd_supply - end_gyd_supply == burn_amount_2
    adjustment_factor_new = (
        adjustment_factor * (new_bal - burn_amount_2 / D("1e18")) / new_bal
    )
    assert gyd_recovery.adjustmentFactor() == scale(adjustment_factor_new)
    new_bal = new_bal_adjusted * adjustment_factor_new
    assert gyd_recovery.balanceAdjustedOf(alice) == scale(new_bal_adjusted)
    assert gyd_recovery.balanceOf(alice) == scale(new_bal)

    # then try to withdraw
    tx = gyd_recovery.initiateWithdrawal(scale(1), {"from": alice})
    withdrawal_id = tx.events["WithdrawalQueued"]["id"]

    chain.sleep(constants.GYD_RECOVERY_WITHDRAWAL_WAIT_DURATION)
    chain.mine()

    start_bal = gyd_token.balanceOf(alice)
    gyd_recovery.withdraw(withdrawal_id, {"from": alice})
    end_bal = gyd_token.balanceOf(alice)
    withdraw_amount_effective = D(1) / adjustment_factor_new * adjustment_factor_new
    assert end_bal - start_bal == scale(withdraw_amount_effective)
    end_bal_effective = (
        new_bal_adjusted - D(1) / adjustment_factor_new
    ) * adjustment_factor_new
    assert gyd_recovery.balanceOf(alice) == scale(end_bal_effective)


@pytest.mark.usefixtures("gyd_alice", "gyd_bob", "gyd_recovery_mining")
def test_rewards_noburn(alice, bob, gyd_recovery, gyd_token, chain):
    """Test accounting of liquidity mining without burns."""
    gyd_amount = scale(2)
    gyd_token.approve(gyd_recovery, gyd_amount, {"from": alice})
    gyd_recovery.deposit(gyd_amount, {"from": alice})

    assert gyd_recovery.stakedBalanceOf(alice) == gyd_amount
    assert gyd_recovery.totalStaked() == gyd_amount

    gyd_amount = scale(4)
    gyd_token.approve(gyd_recovery, gyd_amount, {"from": bob})
    tx = gyd_recovery.deposit(gyd_amount, {"from": bob})

    assert gyd_recovery.stakedBalanceOf(bob) == gyd_amount
    assert gyd_recovery.totalStaked() == scale(6)

    # Note: We don't differentiate between alice's and bob's deposit time, so
    # all calculations will be approximate.
    deposit_time = tx.timestamp

    chain.sleep(7 * 86400)
    chain.mine()

    # Check mining amounts
    time_elapsed = chain[-1]["timestamp"] - deposit_time

    compute_expected = (
        lambda v: v / 6 * time_elapsed * gyd_recovery.rewardsEmissionRate()
    )
    alice_expected = compute_expected(2)
    bob_expected = compute_expected(4)

    assert int(gyd_recovery.claimableRewards(alice)) == pytest.approx(alice_expected, rel=5e-6, abs=1e-12)
    assert int(gyd_recovery.claimableRewards(bob)) == pytest.approx(bob_expected, rel=5e-6, abs=1e-12)

    # Withdraw and check: initiateWithdrawal changes staked balance, executing
    # the withdrawal does not.

    tx = gyd_recovery.initiateWithdrawal(scale(1), {"from": alice})
    withdrawal_id = tx.events["WithdrawalQueued"]["id"]

    assert gyd_recovery.stakedBalanceOf(alice) == scale(1)
    assert gyd_recovery.totalStaked() == scale(5)

    chain.sleep(constants.GYD_RECOVERY_WITHDRAWAL_WAIT_DURATION)
    chain.mine()

    gyd_recovery.withdraw(withdrawal_id, {"from": alice})

    assert gyd_recovery.stakedBalanceOf(alice) == scale(1)
    assert gyd_recovery.totalStaked() == scale(5)


@pytest.mark.usefixtures("gyd_alice", "gyd_bob", "gyd_recovery_mining")
def test_rewards_partialburn_sync(
    alice, bob, admin, gyd_recovery, gyd_token, mock_price_oracle, dai, dai_vault, chain
):
    """Partial burns without joins/exits in between don't have any effect."""
    gyd_amount = scale(2)
    gyd_token.approve(gyd_recovery, gyd_amount, {"from": alice})
    gyd_recovery.deposit(gyd_amount, {"from": alice})

    gyd_amount = scale(4)
    gyd_token.approve(gyd_recovery, gyd_amount, {"from": bob})
    tx = gyd_recovery.deposit(gyd_amount, {"from": bob})

    deposit_time = tx.timestamp

    chain.sleep(7 * 86400)
    chain.mine()

    # Partial burn
    start_gyd_supply = gyd_token.totalSupply()
    recovery_supply = gyd_recovery.totalUnderlying()
    new_price = D("0.75")
    mock_price_oracle.setUSDPrice(dai, scale(new_price), {"from": admin})
    mock_price_oracle.setUSDPrice(dai_vault, scale(new_price), {"from": admin})
    burn_amount = (1 - new_price) * start_gyd_supply
    tx = gyd_recovery.checkAndRun()
    assert tx.events["RecoveryExecuted"]["isFullBurn"] == False
    assert tx.events["RecoveryExecuted"]["tokensBurned"] == burn_amount

    chain.sleep(7 * 86400)
    chain.mine()

    # Check mining amounts
    time_elapsed = chain[-1]["timestamp"] - deposit_time

    compute_expected = (
        lambda v: v / 6 * time_elapsed * gyd_recovery.rewardsEmissionRate()
    )
    alice_expected = compute_expected(2)
    bob_expected = compute_expected(4)

    assert int(gyd_recovery.claimableRewards(alice)) == pytest.approx(alice_expected, rel=5e-6, abs=1e-12)
    assert int(gyd_recovery.claimableRewards(bob)) == pytest.approx(bob_expected, rel=5e-6, abs=1e-12)


@pytest.mark.usefixtures("gyd_alice", "gyd_bob", "gyd_recovery_mining")
def test_rewards_fullburn_async(
    alice, bob, admin, gyd_recovery, gyd_token, mock_price_oracle, dai, dai_vault, chain
):
    """Full burns with a joins in between account correctly for liquidity mining."""
    gyd_amount = scale(2)
    gyd_token.approve(gyd_recovery, gyd_amount, {"from": alice})
    tx = gyd_recovery.deposit(gyd_amount, {"from": alice})
    deposit_time_alice = tx.timestamp

    chain.sleep(7 * 86400)
    chain.mine()

    # Full burn
    start_gyd_supply = gyd_token.totalSupply()
    recovery_supply = gyd_recovery.totalUnderlying()
    new_price = D("0.1")
    mock_price_oracle.setUSDPrice(dai, scale(new_price), {"from": admin})
    mock_price_oracle.setUSDPrice(dai_vault, scale(new_price), {"from": admin})
    tx = gyd_recovery.checkAndRun()
    assert tx.events["RecoveryExecuted"]["isFullBurn"] == True
    burn_time = tx.timestamp

    # No emission happens during the following time.
    chain.sleep(7 * 86400)
    chain.mine()

    gyd_amount = scale(4)
    gyd_token.approve(gyd_recovery, gyd_amount, {"from": bob})
    tx = gyd_recovery.deposit(gyd_amount, {"from": bob})
    deposit_time_bob = tx.timestamp

    chain.sleep(7 * 86400)
    chain.mine()
    end_time = chain[-1]["timestamp"]

    emission_rate = gyd_recovery.rewardsEmissionRate()
    alice_expected = (burn_time - deposit_time_alice) * emission_rate
    bob_expected = (end_time - deposit_time_bob) * emission_rate

    assert int(gyd_recovery.claimableRewards(alice)) == pytest.approx(alice_expected, rel=5e-6, abs=1e-12)
    assert int(gyd_recovery.claimableRewards(bob)) == pytest.approx(bob_expected, rel=5e-6, abs=1e-12)


@pytest.mark.usefixtures("gyd_alice", "gyd_bob", "gyd_recovery_mining")
def test_rewards_partialburn_async(
    alice, bob, admin, gyd_recovery, gyd_token, mock_price_oracle, dai, dai_vault, chain
):
    """Partial burns with a joins in between account correctly for liquidity mining."""
    gyd_amount = scale(6)
    gyd_token.approve(gyd_recovery, gyd_amount, {"from": alice})
    tx = gyd_recovery.deposit(gyd_amount, {"from": alice})
    deposit_time_alice = tx.timestamp

    chain.sleep(7 * 86400)
    chain.mine()

    # Full burn
    start_gyd_supply = gyd_token.totalSupply()
    recovery_supply = gyd_recovery.totalUnderlying()
    new_price = D("0.75")
    mock_price_oracle.setUSDPrice(dai, scale(new_price), {"from": admin})
    mock_price_oracle.setUSDPrice(dai_vault, scale(new_price), {"from": admin})
    burn_amount = (1 - new_price) * start_gyd_supply
    tx = gyd_recovery.checkAndRun()
    assert tx.events["RecoveryExecuted"]["isFullBurn"] == False
    assert tx.events["RecoveryExecuted"]["tokensBurned"] == burn_amount
    burn_time = tx.timestamp

    # No emission happens during the following time.
    chain.sleep(7 * 86400)
    chain.mine()

    gyd_amount = scale(2)
    gyd_token.approve(gyd_recovery, gyd_amount, {"from": bob})
    tx = gyd_recovery.deposit(gyd_amount, {"from": bob})
    deposit_time_bob = tx.timestamp

    chain.sleep(7 * 86400)
    chain.mine()
    end_time = chain[-1]["timestamp"]

    emission_rate = gyd_recovery.rewardsEmissionRate()

    # Alice receives 100% of rewards until bob joins. Then much less according
    # to how much of her funds are still left vs. bob's new funds.
    alice_remaining_postburn = (
        scale(6) * (recovery_supply - burn_amount) / recovery_supply
    )
    share_alice_remaining_postburn = alice_remaining_postburn / (
        alice_remaining_postburn + scale(2)
    )
    alice_expected = (deposit_time_bob - deposit_time_alice) * emission_rate + (
        end_time - deposit_time_bob
    ) * emission_rate * share_alice_remaining_postburn
    bob_expected = (
        (end_time - deposit_time_bob)
        * emission_rate
        * (1 - share_alice_remaining_postburn)
    )

    assert int(gyd_recovery.claimableRewards(alice)) == pytest.approx(
        int(alice_expected), rel=5e-6, abs=1e-12
    )
    assert int(gyd_recovery.claimableRewards(bob)) == pytest.approx(int(bob_expected), rel=5e-6, abs=1e-12)
