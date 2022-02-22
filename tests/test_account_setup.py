from brownie.test.managers.runner import RevertContextManager as reverts
import pytest

from tests.support.utils import scale


def test_transfer_adjusts_sender_balance(accounts, underlying, decimals):
    balance = underlying.balanceOf(accounts[0])
    underlying.transfer(accounts[1], scale(10, decimals), {"from": accounts[0]})

    assert underlying.balanceOf(accounts[0]) == balance - scale(10, decimals)


def test_transfer_adjusts_receiver_balance(accounts, underlying, decimals):
    balance = underlying.balanceOf(accounts[1])
    underlying.transfer(accounts[1], scale(10, decimals), {"from": accounts[0]})

    assert underlying.balanceOf(accounts[1]) == balance + scale(10, decimals)


def test_transfer_fails_from_insufficient_balance(accounts, underlying, decimals):
    with reverts("ERC20: transfer amount exceeds balance"):
        underlying.transfer(
            accounts[2], scale(100, decimals) + 1, {"from": accounts[1]}
        )
