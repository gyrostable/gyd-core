# Usage: brownie run --network=polygon-main $0 {mk_set_vals_stmatic_eclp,get_vals_stmatic_eclp}

from brownie.network.contract import VirtualMachineError
from scripts.mk_gyroconfig_per_pool_setting import mk_pool_setting
from brownie import *
from typing import Union
from tests.support import config_keys
from tests.support.utils import to_decimal as D, scale, unscale, format_to_bytes
from pprint import pprint

def encode_governance_call(
    governanceproxy, gyroconfig, setter: str, key: bytes, value: Union[int, str]
):
    """
    setter: "setUint" or "setAddress"
    """
    return governanceproxy.executeCall.encode_input(
        gyroconfig.address, getattr(gyroconfig, setter).encode_input(key, value)
    )


def mk_set_vals_stmatic_eclp():
    pool_address = "0xf0ad209e2e969EAAA8C882aac71f02D8a047d5c2"
    gyroconfig_address = "0xfdc2e9e03f515804744a40d0f8d25c16e93fbe67"  # The one on Polygon used by vaults
    balancer_fee_collector_address = "0xce88686553686da562ce7cea497ce749da109f9f"
    protocol_swap_fee_perc = D("0.3")

    gyroconfig = GyroConfig[1]  # type: ignore
    assert gyroconfig.address.lower() == gyroconfig_address

    governanceproxy = GovernanceProxy[0]  # type: ignore

    calls = []

    # We don't set GYRO_TREASURY. It's at 0x0 right now, which is ok b/c PROTOCOL_FEE_GYRO_PORTION = 0
    # calls.append(encode_governance_call(governanceproxy, gyroconfig,
    #                                     "setAddress",
    #                                     config_keys.GYRO_TREASURY,
    #                                     ZERO_ADDRESS))
    calls.append(
        encode_governance_call(
            governanceproxy,
            gyroconfig,
            "setAddress",
            config_keys.BAL_TREASURY,
            balancer_fee_collector_address,
        )
    )
    calls.append(
        encode_governance_call(
            governanceproxy,
            gyroconfig,
            "setUint",
            mk_pool_setting(
                config_keys.PROTOCOL_SWAP_FEE_PERC, pool_address=pool_address
            ),
            int(scale(protocol_swap_fee_perc)),
        )
    )
    pprint(calls)

    print("GovernanceProxy:", governanceproxy.address)
    print("GyroConfig:", gyroconfig.address)


def get_vals_stmatic_eclp():
    pool_address = "0xf0ad209e2e969EAAA8C882aac71f02D8a047d5c2"
    gyroconfig_address = "0xfdc2e9e03f515804744a40d0f8d25c16e93fbe67"  # The one on Polygon used by vaults

    gyroconfig = GyroConfig[1]  # type: ignore
    assert gyroconfig.address.lower() == gyroconfig_address

    for key in ["BAL_TREASURY", "GYRO_TREASURY"]:
        try:
            print("global", key, gyroconfig.getAddress(getattr(config_keys, key)))
        except VirtualMachineError:
            print("global", key, "not set")

    for key in ["PROTOCOL_SWAP_FEE_PERC", "PROTOCOL_FEE_GYRO_PORTION"]:
        try:
            print("global", key, unscale(gyroconfig.getUint(getattr(config_keys, key))))
        except VirtualMachineError:
            print("global", key, "not set")


    for key in ["PROTOCOL_SWAP_FEE_PERC", "PROTOCOL_FEE_GYRO_PORTION"]:
        keyb = key.encode()
        # Sanity check
        assert getattr(config_keys, key) == mk_pool_setting(keyb)

        setting = mk_pool_setting(keyb, pool_address=pool_address)
        try:
            print("per-pool", key, unscale(gyroconfig.getUint(setting)))
        except VirtualMachineError:
            print("per-pool", key, "not set")


def main():
    mk_set_vals_stmatic_eclp()

