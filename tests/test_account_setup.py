import brownie
import pytest

# NOTE: needed to avoid instantiating the fitures from within fn_isolation
# because features are dynamically loaded within the parameterized tests
pytestmark = pytest.mark.usefixtures("usdc", "usdt", "dai")


@pytest.mark.parametrize("token_name", ["dai", "usdc", "usdt"])
def test_transfer_adjusts_sender_balance(accounts, token_name, request):
    token = request.getfixturevalue(token_name)
    balance = token.balanceOf(accounts[0])
    token.transfer(accounts[1], 10 ** 18, {"from": accounts[0]})

    assert token.balanceOf(accounts[0]) == balance - 10 ** 18


@pytest.mark.parametrize("token_name", ["dai", "usdc", "usdt"])
def test_transfer_adjusts_receiver_balance(accounts, token_name, request):
    token = request.getfixturevalue(token_name)
    balance = token.balanceOf(accounts[1])
    token.transfer(accounts[1], 10 ** 18, {"from": accounts[0]})

    assert token.balanceOf(accounts[1]) == balance + 10 ** 18


@pytest.mark.parametrize("token_name", ["dai", "usdc", "usdt"])
def test_transfer_fails_from_insufficient_balance(accounts, token_name, request):
    token = request.getfixturevalue(token_name)
    with brownie.reverts("ERC20: transfer amount exceeds balance"):
        token.transfer(accounts[2], 10 ** 18, {"from": accounts[1]})
