import time
from typing import Optional

import web3
from eth_abi.abi import encode_abi
from eth_account.messages import encode_defunct


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
