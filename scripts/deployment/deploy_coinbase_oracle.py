from brownie import TrustedSignerPriceOracle, AssetRegistry  # type: ignore
from scripts.utils import (
    as_singleton,
    get_deployer,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.support.constants import COINBASE_SIGNING_ADDRESS
from tests.support.retrieve_coinbase_prices import fetch_prices, find_price


def _post_prices(deployer, oracle):
    eth_price = find_price(fetch_prices()[0], "ETH")
    oracle.postPrices([eth_price], {"from": deployer, **make_tx_params()})


@with_deployed(TrustedSignerPriceOracle)
def post_prices(oracle):
    _post_prices(get_deployer(), oracle)


@with_gas_usage
@with_deployed(AssetRegistry)
@as_singleton(TrustedSignerPriceOracle)
def main(asset_registry):
    deployer = get_deployer()
    oracle = deployer.deploy(
        TrustedSignerPriceOracle,
        asset_registry,
        COINBASE_SIGNING_ADDRESS,
        **make_tx_params()
    )
    _post_prices(deployer, oracle)
