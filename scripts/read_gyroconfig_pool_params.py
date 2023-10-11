# Read config values for a Gyroscope pool, specifically the MATIC/STMATIC ECLP
# on Polygon.
#
# Usage:
# $ # ...set up WEB3_INFURA_PROJECT_ID in environment...
# $ brownie run --network=polygon-main $0

from eth_utils import keccak
from eth_abi import encode_abi

from typing import Optional, Union
from decimal import Decimal

from brownie import *
from brownie.exceptions import VirtualMachineError


def mk_pool_setting(
    setting: Union[str, bytes],
    pool_type: Optional[bytes] = None,
    pool_address: Optional[str] = None,
):
    """Create a per-pool setting following the cascading GyroConfig logic used by pools.

    setting: Name of the setting.
    pool_type: If not None, the pool type code as a byte string. We create a per-pool-type setting.
    pool_address: If not None, the address of the pool as a byte string. We create a per-pool setting.

    returns: The key to be passed to GyroConfig.{get,set}Uint().

    If pool_address is given, pool_type is ignored. This mirrors GyroConfigHelpers._getPoolSetting().
    """
    if isinstance(setting, str):
        setting = setting.encode()

    if pool_address is not None:
        return keccak(encode_abi(["bytes32", "address"], [setting, pool_address]))
    elif pool_type is not None:
        return keccak(encode_abi(["bytes32", "bytes32"], [setting, pool_type]))
    else:
        return encode_abi(["bytes32"], [setting])


def get_pool_setting_str(gyroconfig, setting: bytes, get_method: str):
    """Get and format pool setting."""
    try:
        v = getattr(gyroconfig, get_method)(setting)
    except VirtualMachineError as e:
        if e.revert_msg == "32":  # error code for key not found
            return "not set"
        raise

    if get_method == "getUint":
        v = unscale(v)
    return str(v)


def main(gyro_config_address, pool_address: Optional[str] = None):
    # TODO SOMEDAY also do per-pool-type values. This is implemented in mk_pool_setting but need some dict of the pool type byte strings somehow.

    # pool = Contract.from_explorer(pool_address)
    # gyroconfig = Contract.from_explorer(pool.gyroConfig)
    gyroconfig = GyroConfig.at(gyro_config_address)  # type: ignore

    for key in ["BAL_TREASURY", "GYRO_TREASURY"]:
        vstr = get_pool_setting_str(gyroconfig, mk_pool_setting(key), "getAddress")
        print(f"global   {key} = {vstr}")

    keys = ["PROTOCOL_SWAP_FEE_PERC", "PROTOCOL_FEE_GYRO_PORTION"]

    for key in keys:
        vstr = get_pool_setting_str(gyroconfig, mk_pool_setting(key), "getUint")
        print(f"global   {key} = {vstr}")

    if pool_address is not None:
        pool_address = pool_address.lower()
        for key in keys:
            vstr = get_pool_setting_str(
                gyroconfig, mk_pool_setting(key, pool_address=pool_address), "getUint"
            )
            print(f"per-pool {key} = {vstr}")


def unscale(x: int) -> Decimal:
    return Decimal(x) / Decimal("1e18")
