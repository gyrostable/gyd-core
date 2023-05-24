from brownie.test.managers.runner import RevertContextManager as reverts
from brownie import ZERO_ADDRESS
from tests.support import error_codes


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


def test_deposit(underlying, alice, vault, decimals):
    underlying.approve(vault, 10**decimals, {"from": alice})
    tx = vault.deposit(10**decimals, 0, {"from": alice})
    assert vault.balanceOf(alice) == 10**decimals
    assert vault.totalSupply() == 10**decimals
    assert vault.totalUnderlying() == 10**decimals
    assert vault.exchangeRate() == 10**18
    assert tx.events["Transfer"][0]["from"] == ZERO_ADDRESS
    assert tx.events["Transfer"][0]["to"] == alice
    assert tx.events["Transfer"][0]["value"] == 10**decimals


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
        total = (i + 1) * 10**decimals
        assert vault.totalUnderlying() == total
        assert vault.totalSupply() == total
        assert vault.exchangeRate() == 10**18
        assert vault.balanceOf(account) == 10**decimals


def test_mint_for_diff_account(alice, bob, vault, underlying, decimals):
    underlying.approve(vault, 10**decimals, {"from": alice})
    initial_alice_balance = underlying.balanceOf(alice)
    tx = vault.depositFor(bob, 10**decimals, 0, {"from": alice})
    assert tx.events["Transfer"][0]["from"] == ZERO_ADDRESS
    assert tx.events["Transfer"][0]["to"] == bob
    assert tx.events["Transfer"][0]["value"] == 10**decimals
    assert vault.balanceOf(bob) == 10**decimals
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
    vault.deposit(deposit_amount, 0, {"from": alice})

    assert underlying.balanceOf(vault) == deposit_amount
    assert vault.totalSupply() == deposit_amount

    previous_balance = underlying.balanceOf(alice)
    tx = vault.withdraw(deposit_amount, 0, {"from": alice})
    assert tx.events["Transfer"][0]["from"] == alice
    assert tx.events["Transfer"][0]["to"] == ZERO_ADDRESS
    assert tx.events["Transfer"][0]["value"] == deposit_amount
    assert underlying.balanceOf(alice) == previous_balance + deposit_amount
    assert vault.balanceOf(alice) == 0
    assert underlying.balanceOf(vault) == 0
    assert vault.totalSupply() == 0
