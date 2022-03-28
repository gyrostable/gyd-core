from brownie import UniswapV3TwapOracle  # type: ignore

from scripts.utils import (
    get_deployer,
    as_singleton,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.fixtures.mainnet_contracts import CHAINLINK_FEEDS, UniswapPools, is_stable
from tests.support.utils import scale


@with_deployed(UniswapV3TwapOracle)
def add_pools(uniswap_v3_twap_oracle):
    deployer = get_deployer()
    pools = [
        getattr(UniswapPools, v) for v in dir(UniswapPools) if not v.startswith("_")
    ]
    for pool in pools:
        uniswap_v3_twap_oracle.registerPool(
            pool, {"from": deployer, **make_tx_params()}
        )


@with_gas_usage
@as_singleton(UniswapV3TwapOracle)
def main():
    return get_deployer().deploy(UniswapV3TwapOracle, **make_tx_params())
