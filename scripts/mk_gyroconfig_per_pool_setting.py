from eth_utils import keccak
from eth_abi import encode_abi

from typing import Optional

# Usage: Edit main(), then run this via just python.
# (there's no argument parsing yet)


def mk_pool_setting(
    setting: bytes,
    pool_type: Optional[bytes] = None,
    pool_address: Optional[str] = None,
):
    """Create a per-pool setting following the cascading logic in GyroConfig.

    setting: Name of the setting. A byte string (b prefix in python).
    pool_type: If not None, the pool type code as a byte string. We create a per-pool-type setting.
    pool_address: If not None, the address of the pool as a byte string. We create a per-pool setting.

    returns: The key to be passed to GyroConfig.{get,set}Uint().

    If pool_address is given, pool_type is ignored. This mirrors GyroConfigHelpers._getPoolSetting().
    """
    if pool_address is not None:
        return keccak(encode_abi(["bytes32", "address"], [setting, pool_address]))
    elif pool_type is not None:
        return keccak(encode_abi(["bytes32", "bytes32"], [setting, pool_type]))
    else:
        return encode_abi(["bytes32"], [setting])


def main():
    pool_address = "0xf0ad209e2e969EAAA8C882aac71f02D8a047d5c2"  # Polygon STMATIC ECLP
    pool_address = pool_address.lower()
    for setting in [b"PROTOCOL_SWAP_FEE_PERC", b"PROTOCOL_FEE_GYRO_PORTION"]:
        print(setting, ":", mk_pool_setting(setting, pool_address=pool_address))


if __name__ == "__main__":
    main()
