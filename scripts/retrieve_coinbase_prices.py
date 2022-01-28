import hashlib
import hmac
import json
import os
import sys
import time
from base64 import b64decode, b64encode

import eth_abi
import requests
import web3
from requests.auth import AuthBase

BASE_URL = "https://api.exchange.coinbase.com"
REQUEST_PATH = "/oracle"
API_KEY = os.environ["COINBASE_API_KEY"]
API_SECRET = os.environ["COINBASE_API_SECRET"]
API_PASSPHRASE = os.environ["COINBASE_API_PASSPHRASE"]
API_VERSION = "2022-01-26"


class CoinbaseWalletAuth(AuthBase):
    def __init__(self, api_key, secret_key):
        self.api_key = api_key
        self.secret_key = b64decode(secret_key)

    def __call__(self, request):
        timestamp = str(int(time.time()))
        message = timestamp + request.method + request.path_url + (request.body or "")
        signature = hmac.new(self.secret_key, message.encode(), hashlib.sha256)

        request.headers.update(
            {
                "CB-ACCESS-SIGN": b64encode(signature.digest()),
                "CB-ACCESS-TIMESTAMP": timestamp,
                "CB-ACCESS-KEY": self.api_key,
                "CB-ACCESS-PASSPHRASE": API_PASSPHRASE,
                "CB-VERSION": API_VERSION,
            }
        )
        return request


auth = CoinbaseWalletAuth(API_KEY, API_SECRET)

r = requests.get(BASE_URL + "/oracle", auth=auth)
result = r.json()
print(json.dumps(result))

message = result["messages"][0]
signature = result["signatures"][0]

w3 = web3.Web3()
signed_hash = w3.solidityKeccak(
    ["string", "bytes32"],
    ["\x19Ethereum Signed Message:\n32", w3.keccak(hexstr=message)],
)
r, s, v = eth_abi.decode_abi(
    ["bytes32", "bytes32", "uint8"], bytes.fromhex(signature[2:])
)
signing_address = w3.eth.account.recoverHash(signed_hash, vrs=(v, r, s))
print(f"signed using: {signing_address}", file=sys.stderr)
