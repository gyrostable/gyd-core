# Library to be imported from `brownie console`, to verify contract deployments.

from brownie import *
from brownie.network.contract import ProjectContract, ContractContainer
from tabulate import tabulate
import pprint
import hexbytes

# from tests.support.config_keys import *
from scripts.read_gyroconfig_pool_params import mk_pool_setting, get_pool_setting

import json

# "proxy" values have to be an instance of TransparentUpgradeableProxy (or FreezableTransparentUpgradeableProxy)

def get_slot(addr: str, slot: str | int, nbytes_low: int = 32):
    return web3.eth.get_storage_at(addr, slot)[-nbytes_low:]


def proxy_get_admin(c: ProjectContract | str):
    """c.admin() is for some reason not public view, so we get it 'raw'"""
    # Magic number from TransparentUpgradeableProxy / ERC1967Upgrade
    slot = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"
    addr = c if isinstance(c, str) else c.address
    return get_slot(addr, slot, 20)


def proxy_get_implementation(c: ProjectContract | str):
    """c.implementation() is for some reason not public view, so we get it 'raw'"""
    # Magic number from TransparentUpgradeableProxy / ERC1967Upgrade
    slot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
    addr = c if isinstance(c, str) else c.address
    return get_slot(addr, slot, 20)


def print_proxy_data(c: ProjectContract | str, tabs: bool = False):
    addr = c if isinstance(c, str) else c.address
    rows = []

    def cname(c):
        return c._name if c is not None else "none"

    admin = proxy_get_admin(addr).hex()
    impl = proxy_get_implementation(addr).hex()

    if tabs:
        # We change the format here; ugly but whatever.
        return print_dict_table(
            {'proxy admin': admin, 'proxy implementation': impl},
            tabs=True
        )

    rows.append(("self", addr, cname(find_known_contract(addr, fail=False))))
    rows.append(("proxy admin", admin, cname(find_known_contract(admin, fail=False))))
    rows.append(("proxy implementation", impl, cname(find_known_contract(impl, fail=False))))
    print(tabulate(rows, headers=["Contract", "Address", "Contract Name if known"]))


def proxied_contract(c: ProjectContract | str, fail: bool = True):
    if not isinstance(c, str):
        proxy = c
    else:
        proxy = find_known_contract(c)
    if not proxy._name == 'FreezableTransparentUpgradeableProxy':
        return proxy

    impl_addr = proxy_get_implementation(proxy).hex()
    impl = find_known_contract(impl_addr)
    return Contract.from_abi(impl._name, proxy.address, impl.abi)


def find_known_contract(addr: str, fail=True):
    # This is a bit insane, thx for nothing brownie.
    contract_containers = [contract for name, contract in globals().items() if isinstance(contract, ContractContainer)]
    for cc in contract_containers:
        for c in cc:
            if c.address.lower() == addr.lower():
                return c
    if fail:
        raise ValueError(f"Unknown address: {addr}")
    return None


def pull_all_field_views(c: ProjectContract):
    view_names = [f['name'] for f in c.abi if f['type'] == 'function' and "view" in f['stateMutability'] and not f['inputs']]
    return {name: getattr(c, name)() for name in view_names}


def print_dict_table(d: dict, tabs: bool = False):
    processed_dict = {key: str(value) if isinstance(value, (str, hexbytes.main.HexBytes)) else pprint.pformat(value, width=20, compact=True) for key, value in d.items()}
    items = list(processed_dict.items())
    if tabs:
        # Format for easy copy&paste into spreadsheet
        print("Key\tValue")
        print("---\t-----")
        for k, v in items:
            print(k, end='')
            for line in v.split("\n"):
                litrim = line.lstrip()
                line = '.' * (len(line) - len(litrim)) + litrim
                print('\t' + line)
    else:
        print(tabulate(items, headers=["Key", "Value"]))


def print_all_field_views(c: ProjectContract, tabs: bool = False):
    print_dict_table(pull_all_field_views(c), tabs=tabs)


def get_arg_view_fcts(c: ProjectContract):
    """Names of all view functions of c which are not 0-adic (and which we can't just  print)"""
    return [f['name'] for f in c.abi if f.get('stateMutability') in ['pure', 'view'] and f['inputs']]


def c_stdops(addr: str):
    """Some standard ops for verification of a known contract"""
    c = find_known_contract(addr)
    print(repr(c))
    print("---")
    is_proxy = proxy_get_implementation(c).hex() != ZERO_ADDRESS
    print("Is Proxy? ", is_proxy)
    if is_proxy:
        print("---")
        print("proxy:")
        print_proxy_data(c, tabs=True)
        c = proxied_contract(c)
        print()
        print("proxied:", repr(c))
    print("---")
    print("0-arg views:")
    print_all_field_views(c, tabs=True)
    print("---")
    print(">0-arg views:")
    print(get_arg_view_fcts(c))
    return c


def pull_gyroconfig(gyroconfig: ProjectContract, dtypes_inc=(), dtypes_excl=()):
    def dtype_matches(dt):
        return (not dtypes_inc or dt in dtypes_inc) and (dt not in dtypes_excl)
    keys = gyroconfig.listKeys()

    ret = []
    for key in keys:
        try:
            dkey = key.decode()
        except UnicodeDecodeError:
            dkey = "(garbage)"
        dt, frozen = gyroconfig.getConfigMeta(key)
        if not dtype_matches(dt):
            continue
        if dt == 1:
            v = gyroconfig.getAddress(key)
        elif dt == 2:
            v = gyroconfig.getUint(key)
        else:
            raise ValueError(f"Unknown dtype {dt}")
        ret.append({'Key': key, 'Key (decoded)': dkey, 'Frozen': frozen, 'Value': v})
    return ret

def pull_gyroconfig_pool_specific_keys(gyroconfig: ProjectContract, map_json_vaults_path: str):
    """
        map_json_vaults_path: path to map.json inside vaults. (this is where pools are registered)
    """
    # TODO maybe this function shouldn't be here but in vaults.
    with open(map_json_vaults_path) as f:
        map_json_vaults = json.load(f)

    contract2pool_type = {
        'Gyro2CLPPool': "2CLP",
        'Gyro3CLPPool': "3CLP",
        'GyroECLPPool': "ECLP",
    }
    dkeys = ["PROTOCOL_SWAP_FEE_PERC", "PROTOCOL_FEE_GYRO_PORTION"]

    ret = []
    for dpool_type in contract2pool_type.values():
        for dkey in dkeys:
            key = mk_pool_setting(dkey, pool_type=dpool_type.encode())
            v = get_pool_setting(gyroconfig, key, 'getUint')
            if v is not None:
                ret.append({
                    'pool_type': dpool_type,
                    'dkey': dkey,
                    'key': "0x" + key.hex(),
                    'value': v,
                })

    for cname in contract2pool_type.keys():
        for dpool_address in set(map_json_vaults.get(str(chain.id), []).get(cname, [])):
            pool_address = dpool_address.lower()
            for dkey in dkeys:
                key = mk_pool_setting(dkey, pool_address=pool_address)
                v = get_pool_setting(gyroconfig, key, 'getUint')
                if v is not None:
                    ret.append({
                        'pool_address': pool_address,
                        'dkey': dkey,
                        'key': "0x" + key.hex(),
                        'value': v,
                    })

    return ret
