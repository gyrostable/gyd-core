from brownie import TrustedSignerPriceOracle, GyroConfig  # type: ignore
from scripts.utils import (
    as_singleton,
    get_deployer,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.support import config_keys
from tests.support.constants import COINBASE_SIGNING_ADDRESS
from tests.support.retrieve_coinbase_prices import fetch_prices, find_price


def _post_prices(deployer, oracle):
    eth_price = find_price(fetch_prices()[0], "ETH")
    oracle.postPrices([eth_price], {"from": deployer, **make_tx_params()})


@with_deployed(TrustedSignerPriceOracle)
def post_prices(oracle):
    _post_prices(get_deployer(), oracle)


@with_gas_usage
@with_deployed(GyroConfig)
@as_singleton(TrustedSignerPriceOracle)
def main(gyro_config):
    asset_registry_address = gyro_config.getAddress(config_keys.ASSET_REGISTRY_ADDRESS)
    deployer = get_deployer()
    deployer.deploy(
        TrustedSignerPriceOracle,
        asset_registry_address,
        COINBASE_SIGNING_ADDRESS,
        False,
        **make_tx_params()
    )
