import time
from decimal import Decimal
from typing import Optional

import pytest
import web3
from brownie import ETH_ADDRESS
from brownie.test.managers.runner import RevertContextManager as reverts
from eth_abi.abi import encode_abi
from eth_account.messages import encode_defunct
from tests.fixtures.mainnet_contracts import TokenAddresses
from tests.support import error_codes
from tests.support.constants import COINBASE_SIGNING_ADDRESS
from tests.support.utils import scale

SAMPLE_MESSAGE = "0x00000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000061f1824800000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000008ebdae68f0000000000000000000000000000000000000000000000000000000000000006707269636573000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000034254430000000000000000000000000000000000000000000000000000000000"
SAMPLE_SIGNATURE = "0xc53ce1cf4e1b4f6294a0c35812792efceb316bac4b3b5451659bd36ff9fbf3b56d42187e00d0169730a766d53d83bdc56653bcd8b70e8c168e1ebcd851a8f367000000000000000000000000000000000000000000000000000000000000001b"

PRICE_DECIMALS = 6


@pytest.fixture(scope="module")
def add_assets_to_registry(asset_registry, admin):
    asset_registry.setAssetAddress("ETH", TokenAddresses.ETH, {"from": admin})
    asset_registry.setAssetAddress("BTC", TokenAddresses.WBTC, {"from": admin})
    asset_registry.setAssetAddress("DAI", TokenAddresses.DAI, {"from": admin})


def sign_message(message, signer):
    hashed_message = web3.Web3().keccak(hexstr=message)
    message_to_sign = encode_defunct(hexstr=hashed_message.hex())
    signed_message = web3.Web3().eth.account.sign_message(
        message_to_sign, private_key=signer.private_key
    )
    sig = signed_message.signature
    encoded_signature = encode_abi(
        ["bytes32", "bytes32", "uint8"], [sig[:32], sig[32:64], sig[-1]]
    )
    return "0x" + encoded_signature.hex()


def make_message(key: str, price: int, timestamp: Optional[int] = None):
    if timestamp is None:
        timestamp = int(time.time())
    encoded = encode_abi(
        ["string", "uint256", "string", "uint256"], ["prices", timestamp, key, price]
    )
    return "0x" + encoded.hex()


def test_verify_message(coinbase_price_oracle):
    recovered_address = coinbase_price_oracle.callVerifyMessage(
        SAMPLE_MESSAGE, SAMPLE_SIGNATURE
    )
    assert recovered_address == COINBASE_SIGNING_ADDRESS


def test_decode_message(coinbase_price_oracle):
    timestamp, key, price = coinbase_price_oracle.callDecodeMessage(SAMPLE_MESSAGE)
    assert timestamp == 1643217480
    assert key == "BTC"
    assert price == 38316729999

    encoded_message = make_message("ETH", 2395990000, 1643383175)
    timestamp, key, price = coinbase_price_oracle.callDecodeMessage(encoded_message)
    assert timestamp == 1643383175
    assert key == "ETH"
    assert price == 2395990000


def test_verify_locally_signed_message(local_signer_price_oracle, price_signer):
    encoded_message = make_message("ETH", 2395990000, 1643383175)
    signature = sign_message(encoded_message, price_signer)

    recovered_address = local_signer_price_oracle.callVerifyMessage(
        encoded_message, signature
    )
    assert recovered_address == price_signer.address


@pytest.mark.usefixtures("add_assets_to_registry")
def test_post_price(local_signer_price_oracle, price_signer):
    timestamp = int(time.time())
    unscaled_price = Decimal("2395.99")
    encoded_message = make_message(
        "ETH", int(scale(unscaled_price, PRICE_DECIMALS)), timestamp
    )
    signature = sign_message(encoded_message, price_signer)

    with reverts(error_codes.ASSET_NOT_SUPPORTED):
        local_signer_price_oracle.getPriceUSD(ETH_ADDRESS)

    tx = local_signer_price_oracle.postPrice(encoded_message, signature)
    expected_price = scale(unscaled_price, 18)
    assert tx.events["PriceUpdated"]["asset"] == ETH_ADDRESS
    assert tx.events["PriceUpdated"]["price"] == expected_price
    assert tx.events["PriceUpdated"]["timestamp"] == timestamp

    assert local_signer_price_oracle.getPriceUSD(ETH_ADDRESS) == expected_price
    assert local_signer_price_oracle.getLastUpdate(ETH_ADDRESS) == timestamp


@pytest.mark.usefixtures("add_assets_to_registry")
def test_post_prices(local_signer_price_oracle, price_signer, asset_registry):
    prices = [
        ("ETH", Decimal("2395.99")),
        ("BTC", Decimal("38316.7")),
        ("DAI", Decimal("1.013")),
    ]
    signed_prices = [
        (
            m := make_message(key, int(scale(price, PRICE_DECIMALS))),
            sign_message(m, price_signer),
        )
        for key, price in prices
    ]
    tx = local_signer_price_oracle.postPrices(signed_prices)
    assert len(tx.events["PriceUpdated"]) == len(prices)

    for asset_name, unscaled_price in prices:
        asset_address = asset_registry.getAssetAddress(asset_name)
        expected_price = scale(unscaled_price, 18)
        assert local_signer_price_oracle.getPriceUSD(asset_address) == expected_price


def test_post_inexistent_asset(local_signer_price_oracle, price_signer):
    encoded_message = make_message("NAA", 12345678)
    signature = sign_message(encoded_message, price_signer)

    with reverts(error_codes.ASSET_NOT_SUPPORTED):
        local_signer_price_oracle.postPrice(encoded_message, signature)


@pytest.mark.usefixtures("add_assets_to_registry")
def test_post_stale_price(local_signer_price_oracle, price_signer):
    expired_timestamp = int(time.time() - 86400 * 2)
    encoded_message = make_message(
        "ETH", int(scale(Decimal("2395.99"), PRICE_DECIMALS)), expired_timestamp
    )
    signature = sign_message(encoded_message, price_signer)

    with reverts(error_codes.STALE_PRICE):
        local_signer_price_oracle.postPrice(encoded_message, signature)


@pytest.mark.usefixtures("add_assets_to_registry")
def test_get_price_usd_stale_price(local_signer_price_oracle, price_signer, chain):
    unscaled_price = Decimal("2395.99")
    encoded_message = make_message("ETH", int(scale(unscaled_price, PRICE_DECIMALS)))
    signature = sign_message(encoded_message, price_signer)

    local_signer_price_oracle.postPrice(encoded_message, signature)

    expected_price = scale(unscaled_price, 18)
    assert local_signer_price_oracle.getPriceUSD(ETH_ADDRESS) == expected_price

    chain.sleep(86401)
    chain.mine()

    with reverts(error_codes.STALE_PRICE):
        local_signer_price_oracle.getPriceUSD(ETH_ADDRESS)
