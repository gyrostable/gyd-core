from brownie import UniswapV3TwapOracle  # type: ignore

from scripts.utils import (
    get_deployer,
    as_singleton,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.fixtures.mainnet_contracts import UniswapPools


@with_deployed(UniswapV3TwapOracle)
def add_pools(uniswap_v3_twap_oracle):
    deployer = get_deployer()
    for pool in UniswapPools.all_pools():
        uniswap_v3_twap_oracle.registerPool(
            pool, {"from": deployer, **make_tx_params()}
        )


@with_gas_usage
@as_singleton(UniswapV3TwapOracle)
def main():
    return get_deployer().deploy(UniswapV3TwapOracle, **make_tx_params())
