from brownie import accounts


def test_mock_lp_token_exchanger(mock_lp_token_exchanger, usdc, alice):
    balance = alice.balance()
    mock_lp_token_exchanger.deposit(
        ("0x6b175474e89094c44da98b954eedeac495271d0f", 400e18)
    )
