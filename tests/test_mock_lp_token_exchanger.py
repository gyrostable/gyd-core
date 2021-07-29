from brownie import accounts


def test_mock_lp_token_exchanger_deposit_for(mock_lp_token_exchanger, usdc, alice):
    usdc.approve(mock_lp_token_exchanger, 100, {"from": alice})
    tx = mock_lp_token_exchanger.depositFor((usdc, 50), alice)

    assert usdc.balanceOf(alice) == 50
    assert usdc.balanceOf(mock_lp_token_exchanger) == 50
    assert tx.return_value == 25
