# Library to be imported from `brownie console`, to verify contract deployments.

from brownie import *
from brownie.network.contract import ProjectContract, ContractContainer
from tabulate import tabulate
import pprint
import hexbytes

from tests.support.config_keys import *

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


def print_proxy_data(c: ProjectContract | str):
    addr = c if isinstance(c, str) else c.address
    rows = []

    def cname(c):
        return c._name if c is not None else "none"

    rows.append(("self", addr, cname(find_known_contract(addr, fail=False))))
    admin = proxy_get_admin(addr).hex()
    rows.append(("admin", admin, cname(find_known_contract(admin, fail=False))))
    impl = proxy_get_implementation(addr).hex()
    rows.append(("implementation", impl, cname(find_known_contract(impl, fail=False))))
    print(tabulate(rows, headers=["Contract", "Address", "Contract Name if known"]))


def proxied_contract(c: ProjectContract | str):
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


def print_dict_table(d: dict):
    processed_dict = {key: str(value) if isinstance(value, (str, hexbytes.main.HexBytes)) else pprint.pformat(value, width=20, compact=True) for key, value in d.items()}
    items = list(processed_dict.items())
    print(tabulate(items, headers=["Key", "Value"]))

def print_all_field_views(c: ProjectContract):
    print_dict_table(pull_all_field_views(c))

