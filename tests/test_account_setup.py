import brownie
import pytest


def test_transfer_adjusts_sender_balance(accounts, dai):
    balance = dai.balanceOf(accounts[0])
    dai.transfer(accounts[1], 10 ** 18, {"from": accounts[0]})

    assert dai.balanceOf(accounts[0]) == balance - 10 ** 18


def test_transfer_adjusts_receiver_balance(accounts, dai):
    balance = dai.balanceOf(accounts[1])
    dai.transfer(accounts[1], 10 ** 18, {"from": accounts[0]})

    assert dai.balanceOf(accounts[1]) == balance + 10 ** 18


def test_transfer_fails_from_insufficient_balance(accounts, dai):
    with brownie.reverts("Insufficient balance"):
        dai.transfer(accounts[2], 10 ** 18, {"from": accounts[1]})


def test_transfer_adjusts_sender_balance(accounts, usdt):
    balance = usdt.balanceOf(accounts[0])
    usdt.transfer(accounts[1], 10 ** 18, {"from": accounts[0]})

    assert usdt.balanceOf(accounts[0]) == balance - 10 ** 18


def test_transfer_adjusts_receiver_balance(accounts, usdt):
    balance = usdt.balanceOf(accounts[1])
    usdt.transfer(accounts[1], 10 ** 18, {"from": accounts[0]})

    assert usdt.balanceOf(accounts[1]) == balance + 10 ** 18


def test_transfer_fails_from_insufficient_balance(accounts, usdt):
    with brownie.reverts("Insufficient balance"):
        usdt.transfer(accounts[2], 10 ** 18, {"from": accounts[1]})


def test_transfer_adjusts_sender_balance(accounts, usdc):
    balance = usdc.balanceOf(accounts[0])
    usdc.transfer(accounts[1], 10 ** 18, {"from": accounts[0]})

    assert usdc.balanceOf(accounts[0]) == balance - 10 ** 18


def test_transfer_adjusts_receiver_balance(accounts, usdc):
    balance = usdc.balanceOf(accounts[1])
    usdc.transfer(accounts[1], 10 ** 18, {"from": accounts[0]})

    assert usdc.balanceOf(accounts[1]) == balance + 10 ** 18


def test_transfer_fails_from_insufficient_balance(accounts, usdc):
    with brownie.reverts("Insufficient balance"):
        usdc.transfer(accounts[2], 10 ** 18, {"from": accounts[1]})
