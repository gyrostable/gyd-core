import os
import sys
from functools import lru_cache, wraps
from typing import Any, Dict, cast

import brownie
from brownie import AssetRegistry, GyroConfig, GovernanceProxy, FreezableTransparentUpgradeableProxy, ProxyAdmin, interface  # type: ignore
from brownie import accounts, network
from brownie.network.account import ClefAccount, LocalAccount

DEV_CHAIN_IDS = {1337}

REQUIRED_CONFIRMATIONS = 1
MAINNET_DEPLOYER_ADDRESS = "0x8780779CAF2bC6D402DA5c3EC79A5007bB2edD90"

MAINNET_DAO_TREASURY_ADDRESS = "0x9543b9F3450C17f1e5E558cC135fD8964dbef92a"

GYRO_CONFIG_POLYGON_ADDRESS = "0x3c00e4663be7262E50251380EBE5fE4A17e68B51"
GYRO_ASSET_REGISTRY_ADDRESS = "0x0FEfDfCa029822C18ae73c2b76c4602949621fe1"
GYFI_TOKEN_MAINNET_ADDRESS = "0x70c4430f9d98B4184A4ef3E44CE10c320a8B7383"
GYFI_TOKEN_POLYGON_ADDRESS = "0x815c288dD62a761025f69B7dac2C93143Da4c0a8"

BROWNIE_GWEI = os.environ.get("BROWNIE_GWEI", "35")
BROWNIE_PRIORITY_GWEI = os.environ.get("BROWNIE_PRIORITY_GWEI")
BROWNIE_ACCOUNT_PASSWORD = os.environ.get("BROWNIE_ACCOUNT_PASSWORD")


def get_token_name_and_symbol():
    if brownie.chain.id == 137:
        return "Proto Gyro Dollar", "p-GYD"
    return "Gyro Dollar", "GYD"


def is_live():
    return network.chain.id not in DEV_CHAIN_IDS


def abort(reason, code=1):
    print(f"error: {reason}", file=sys.stderr)
    sys.exit(code)


def connect_to_clef():
    if not any(isinstance(acc, ClefAccount) for acc in accounts):
        print("Connecting to clef...")
        accounts.connect_to_clef()


def get_clef_account(address: str):
    connect_to_clef()
    return find_account(address)


def find_account(address: str) -> LocalAccount:
    matching = [acc for acc in accounts if acc.address == address]
    if not matching:
        raise ValueError(f"could not find account for {address}")
    return cast(LocalAccount, matching[0])


def make_tx_params():
    tx_params: Dict[str, Any] = {
        "required_confs": REQUIRED_CONFIRMATIONS,
    }
    if BROWNIE_PRIORITY_GWEI:
        tx_params["priority_fee"] = f"{BROWNIE_PRIORITY_GWEI} gwei"
    else:
        tx_params["gas_price"] = f"{BROWNIE_GWEI} gwei"
    return tx_params


@lru_cache()
def get_deployer():
    chain_id = network.chain.id
    if not is_live():
        return accounts[0]
    if chain_id == 1111:  # live-mainnet-fork
        return find_account(MAINNET_DEPLOYER_ADDRESS)
    if chain_id == 1:  # mainnet
        if os.environ.get("USE_CLEF"):
            return get_clef_account(MAINNET_DEPLOYER_ADDRESS)
        else:
            return cast(
                LocalAccount, accounts.load("ftl-deployer", BROWNIE_ACCOUNT_PASSWORD)  # type: ignore
            )
    if chain_id == 137:  # polygon
        return cast(
            LocalAccount, accounts.load("ftl-deployer", BROWNIE_ACCOUNT_PASSWORD)  # type: ignore
        )
    if chain_id == 42161:  # arbitrum
        return cast(
            LocalAccount, accounts.load("ftl-deployer", BROWNIE_ACCOUNT_PASSWORD)  # type: ignore
        )
    if chain_id == 10:  # optimism
        return cast(
            LocalAccount, accounts.load("ftl-deployer", BROWNIE_ACCOUNT_PASSWORD)  # type: ignore
        )
    if chain_id == 1101:  # zkevm
        return cast(
            LocalAccount, accounts.load("ftl-deployer", BROWNIE_ACCOUNT_PASSWORD)  # type: ignore
        )
    if chain_id == 42:  # kovan
        return cast(
            LocalAccount, accounts.load("kovan-deployer", BROWNIE_ACCOUNT_PASSWORD)  # type: ignore
        )
    raise ValueError(f"chain id {chain_id} not yet supported")


def with_gas_usage(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        balance = get_deployer().balance()
        result = f(*args, **kwargs)
        gas_used = float(balance - get_deployer().balance()) / 1e18
        print(f"Gas used in deployment: {gas_used:.4f} ETH")
        return result

    return wrapper


def as_singleton(Contract):
    def wrapped(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            if len(Contract) == 0:
                return f(*args, **kwargs)

            print(f"{Contract.deploy._name} already deployed, skipping")

        return wrapper

    return wrapped


def get_gyro_config():
    if brownie.chain.id == 137:
        return GyroConfig.at(GYRO_CONFIG_POLYGON_ADDRESS)
    return GyroConfig[0]


def get_dao_treasury():
    if brownie.chain.id == 1:
        return MAINNET_DAO_TREASURY_ADDRESS
    if brownie.chain.id == 1337:
        return accounts[8]
    raise ValueError("GYFI token not available on this network")


def get_gyfi_token():
    if brownie.chain.id == 1:
        return interface.ERC20(GYFI_TOKEN_MAINNET_ADDRESS)
    if brownie.chain.id == 137:
        return interface.ERC20(GYFI_TOKEN_POLYGON_ADDRESS)
    raise ValueError("GYFI token not available on this network")


def get_asset_registry():
    if brownie.chain.id == 137:
        return AssetRegistry.at(GYRO_ASSET_REGISTRY_ADDRESS)
    return AssetRegistry[0]


def with_deployed(Contract):
    def wrapped(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            if len(Contract) == 0:
                abort(f"{Contract.deploy._name} not deployed")

            if Contract == GyroConfig:
                contract = get_gyro_config()
            elif Contract == AssetRegistry:
                contract = get_asset_registry()
            else:
                contract = Contract[-1]

            result = f(contract, *args, **kwargs)
            return result

        return wrapper

    return wrapped


def deploy_proxy(contract, init_data=b"", config_key=None, overwrite_proxy=False):
    deployer = get_deployer()
    # proxy_admin = ProxyAdmin[0]
    proxy_admin = ProxyAdmin.at("0x581aE43498196e3Dc274F3F23FF7718d287BC2C6")
    proxy = deployer.deploy(
        FreezableTransparentUpgradeableProxy,
        contract,
        proxy_admin,
        init_data,
        **make_tx_params(),
    )
    if config_key:
        gyro_config = get_gyro_config()
        GovernanceProxy[0].executeCall(
            gyro_config,
            gyro_config.setAddress.encode_input(config_key, proxy),
            {"from": deployer, **make_tx_params()},
        )
    if not overwrite_proxy:
        return proxy
    container = getattr(brownie, contract._name)

    FreezableTransparentUpgradeableProxy.remove(proxy)
    container.remove(contract)
    container.at(proxy.address)
    return container
