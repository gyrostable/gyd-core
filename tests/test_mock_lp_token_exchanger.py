from brownie import accounts


def test_mock_lp_token_exchanger_deposit_for(mock_lp_token_exchanger, usdc, alice):
    usdc.transfer(alice, 100, {"from": accounts[0]})
    usdc.approve(mock_lp_token_exchanger, 100, {"from": alice})
    tx = mock_lp_token_exchanger.depositFor((usdc, 50), alice)

    assert usdc.balanceOf(alice) == 50
    assert usdc.balanceOf(mock_lp_token_exchanger) == 50
    assert tx.return_value == 25


def test_mock_lp_token_exchanger_withdraw_for(mock_lp_token_exchanger, alice, lp_token):
    lp_token.transfer(mock_lp_token_exchanger, 100, {"from": accounts[0]})
    lp_token.approve(alice, 100, {"from": mock_lp_token_exchanger})
    tx = mock_lp_token_exchanger.withdrawFor((lp_token, 50), alice)
