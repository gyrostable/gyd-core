from brownie.test.managers.runner import RevertContextManager as reverts
from brownie import ZERO_ADDRESS
from tests.support import error_codes

DEAD_ADDRESS = "0x000000000000000000000000000000000000dEaD"


def test_deposit_insufficient_funds(underlying, alice, vault, decimals):
    assert underlying.allowance(alice, vault) == 0
    assert vault.underlying() == underlying
    underlying.approve(vault, underlying.balanceOf(alice) + 1, {"from": alice})
    with reverts("ERC20: transfer amount exceeds balance"):
        vault.deposit(underlying.balanceOf(alice) + 1, 0, {"from": alice})


def test_deposit_insufficient_allowance(underlying, alice, vault, decimals):
    assert underlying.allowance(alice, vault) == 0
    with reverts("ERC20: insufficient allowance"):
        vault.deposit(10**decimals, 0, {"from": alice})


def _adjust_with_burned(amount, decimals):
    to_burn = 10 if decimals <= 6 else 10**3
    return amount - to_burn


def test_deposit(underlying, alice, vault, decimals):
    underlying.approve(vault, 10**decimals, {"from": alice})
    tx = vault.deposit(10**decimals, 0, {"from": alice})
    assert vault.balanceOf(alice) == _adjust_with_burned(10**decimals, decimals)
    assert vault.totalSupply() == 10**decimals
    assert vault.totalUnderlying() == 10**decimals
    assert vault.exchangeRate() == 10**18

    assert tx.events["Transfer"][0]["from"] == ZERO_ADDRESS
    assert tx.events["Transfer"][0]["to"] == DEAD_ADDRESS
    assert tx.events["Transfer"][0]["value"] == 10 if decimals <= 6 else 10**3

    assert tx.events["Transfer"][1]["from"] == ZERO_ADDRESS
    assert tx.events["Transfer"][1]["to"] == alice
    assert tx.events["Transfer"][1]["value"] == _adjust_with_burned(
        10**decimals, decimals
    )


def test_multiple_deposits(underlying, alice, bob, charlie, vault, decimals):
    underlying.approve(vault, 10**decimals, {"from": alice})
    underlying.approve(vault, 10**decimals, {"from": bob})
    underlying.approve(vault, 10**decimals, {"from": charlie})

    assert vault.balanceOf(alice) == 0
    assert vault.balanceOf(bob) == 0
    assert vault.balanceOf(charlie) == 0
    assert vault.totalSupply() == 0
    assert vault.exchangeRate() == 10**18

    for i, account in enumerate([alice, bob, charlie]):
        vault.deposit(10**decimals, 0, {"from": account})
        amount_minted = (
            _adjust_with_burned(10**decimals, decimals) if i == 0 else 10**decimals
        )
        total = 10**decimals * (i + 1)
        assert vault.totalUnderlying() == total
        assert vault.totalSupply() == total
        assert vault.exchangeRate() == 10**18
        assert vault.balanceOf(account) == amount_minted


def test_mint_for_diff_account(alice, bob, vault, underlying, decimals):
    underlying.approve(vault, 10**decimals, {"from": alice})
    initial_alice_balance = underlying.balanceOf(alice)

    tx = vault.depositFor(bob, 10**decimals, 0, {"from": alice})
    amount_minted = _adjust_with_burned(10**decimals, decimals)
    assert tx.events["Transfer"][1]["from"] == ZERO_ADDRESS
    assert tx.events["Transfer"][1]["to"] == bob
    assert tx.events["Transfer"][1]["value"] == amount_minted
    assert vault.balanceOf(bob) == amount_minted
    assert vault.balanceOf(alice) == 0
    assert underlying.balanceOf(alice) == initial_alice_balance - 10**decimals


def test_withdraw_fail_insufficient_balance(alice, vault, decimals, underlying):
    deposit_amount = 10**decimals
    underlying.approve(vault, deposit_amount, {"from": alice})
    vault.deposit(deposit_amount, 0, {"from": alice})
    assert vault.totalSupply() == deposit_amount
    with reverts(error_codes.INSUFFICIENT_BALANCE):
        vault.withdraw(2 * deposit_amount, 0, {"from": alice})


def test_successful_withdraw(alice, vault, underlying, decimals):
    deposit_amount = 10**decimals
    underlying.approve(vault, deposit_amount, {"from": alice})
    amount_minted = _adjust_with_burned(10**decimals, decimals)

    vault.deposit(deposit_amount, 0, {"from": alice})

    assert underlying.balanceOf(vault) == deposit_amount
    assert vault.totalSupply() == deposit_amount

    previous_balance = underlying.balanceOf(alice)
    tx = vault.withdraw(amount_minted, 0, {"from": alice})
    assert tx.events["Transfer"][0]["from"] == alice
    assert tx.events["Transfer"][0]["to"] == ZERO_ADDRESS
    assert tx.events["Transfer"][0]["value"] == amount_minted
    assert underlying.balanceOf(alice) == previous_balance + amount_minted
    assert vault.balanceOf(alice) == 0
    assert underlying.balanceOf(vault) == deposit_amount - amount_minted
    assert vault.totalSupply() == deposit_amount - amount_minted
