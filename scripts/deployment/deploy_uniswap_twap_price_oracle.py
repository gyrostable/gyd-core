from brownie import GovernanceProxy, UniswapV3TwapOracle, web3  # type: ignore

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
    current_pools = {
        web3.toChecksumAddress(p) for p in uniswap_v3_twap_oracle.getPools()
    }
    for pool in UniswapPools.all_pools():
        if web3.toChecksumAddress(pool) not in current_pools:
            uniswap_v3_twap_oracle.registerPool(
                pool, {"from": deployer, **make_tx_params()}
            )


@with_gas_usage
@as_singleton(UniswapV3TwapOracle)
@with_deployed(GovernanceProxy)
def main(governance_proxy):
    return get_deployer().deploy(
        UniswapV3TwapOracle, governance_proxy, **make_tx_params()
    )
