import time

from brownie import interface  # type: ignore
import pytest
from tests.support.constants import (
    DAI_ADDRESS,
    SUSHISWAP_ROUTER,
    UNISWAP_ROUTER,
    USDC_ADDRESS,
    WBTC_ADDRESS,
    WETH_ADDRESS,
)
from tests.support.utils import scale

UNSCALED_MINT_AMOUNT = 10_000
DEFAULT_MINT_AMOUNT = scale(UNSCALED_MINT_AMOUNT)
USDC_DEFAULT_MINT_AMOUNT = scale(UNSCALED_MINT_AMOUNT, 6)


def get_uniswappish_routers():
    uniswap_router = interface.UniswapRouter02(UNISWAP_ROUTER)
    sushiswap_router = interface.UniswapRouter02(SUSHISWAP_ROUTER)
    return [uniswap_router, sushiswap_router]


def mint_coin_for(account, coin, token_amount=DEFAULT_MINT_AMOUNT):
    if hasattr(coin, "address"):
        coin = coin.address
    deadline = int(time.time()) + 4 * 86400
    exc = None
    path = [WETH_ADDRESS, coin]
    previous_balance = interface.ERC20(coin).balanceOf(account)
    for router in get_uniswappish_routers():
        try:
            amounts_in = router.getAmountsIn(token_amount, path)
            router.swapETHForExactTokens(
                token_amount,
                path,
                account,
                deadline,
                {"from": account, "value": amounts_in[0]},
            )
            return interface.ERC20(coin).balanceOf(account) - previous_balance
        except ValueError as ex:
            exc = ex

    assert exc is not None
    raise exc


@pytest.fixture(scope="module")
def dai(Token, accounts, is_forked):
    if is_forked:
        token = interface.ERC20(DAI_ADDRESS)
        mint_coin_for(accounts[0], token, DEFAULT_MINT_AMOUNT)
    else:
        token = Token.deploy(
            "Dai Token", "DAI", 18, scale(10_000), {"from": accounts[0]}
        )
    for i in range(1, 10):
        token.transfer(accounts[i], scale(100), {"from": accounts[0]})
    yield token


@pytest.fixture(scope="module")
def sdt(Token, accounts):
    token = Token.deploy("SDT Token", "SDT", 18, scale(10_000), {"from": accounts[0]})
    for i in range(1, 10):
        token.transfer(accounts[i], scale(100), {"from": accounts[0]})
    yield token


@pytest.fixture(scope="module")
def abc(Token, accounts):
    token = Token.deploy("ABC Token", "ABC", 18, scale(10_000), {"from": accounts[0]})
    for i in range(1, 10):
        token.transfer(accounts[i], scale(100), {"from": accounts[0]})
    yield token


@pytest.fixture(scope="module")
def usdc(Token, accounts, is_forked):
    if is_forked:
        token = interface.ERC20(USDC_ADDRESS)
        mint_coin_for(accounts[0], token, USDC_DEFAULT_MINT_AMOUNT)
    else:
        token = Token.deploy(
            "USDC Token", "USDC", 6, scale(10_000, 6), {"from": accounts[0]}
        )
    for i in range(1, 10):
        token.transfer(accounts[i], scale(100, 6), {"from": accounts[0]})
    yield token


@pytest.fixture(scope="module")
def mock_gyfi(Token, admin):
    token = Token.deploy("GYFI", "GYFI", 18, scale(10_000, 18), {"from": admin})
    yield token


@pytest.fixture(scope="module")
def usdt(Token, accounts, is_forked):
    if is_forked:
        token = interface.ERC20(USDC_ADDRESS)
        mint_coin_for(accounts[0], token, USDC_DEFAULT_MINT_AMOUNT)
    else:
        token = Token.deploy(
            "Tether", "USDT", 6, scale(10_000, 6), {"from": accounts[0]}
        )
    for i in range(1, 10):
        token.transfer(accounts[i], scale(100, 6), {"from": accounts[0]})
    yield token


@pytest.fixture(scope="module")
def weth(Token, interface, is_forked, accounts):
    if is_forked:
        token = interface.IWETH(WETH_ADDRESS)
        token.deposit({"from": accounts[0], "value": scale(100)})
    else:
        token = Token.deploy(
            "Wrapped Ether", "WETH", 18, scale(100), {"from": accounts[0]}
        )
    for i in range(1, 10):
        token.transfer(accounts[i], scale(1), {"from": accounts[0]})
    yield token


@pytest.fixture(scope="module")
def wbtc(Token, accounts, is_forked):
    if is_forked:
        token = interface.ERC20(WBTC_ADDRESS)
        mint_coin_for(accounts[0], token, scale(30, 8))
    else:
        token = Token.deploy(
            "Wrapped Bitcoin", "WBTC", 8, scale(30, 8), {"from": accounts[0]}
        )
    for i in range(1, 10):
        token.transfer(accounts[i], scale("0.5", 6), {"from": accounts[0]})
    yield token
