from brownie import TellorOracle  # type: ignore
from scripts.utils import (
    as_singleton,
    get_deployer,
    make_tx_params,
    with_gas_usage,
)
from tests.fixtures.mainnet_contracts import TokenAddresses
from tests.support.constants import STALE_PRICE_DELAY, TELLOR_ORACLE_ADDRESS


@with_gas_usage
@as_singleton(TellorOracle)
def main():
    deployer = get_deployer()
    deployer.deploy(
        TellorOracle,
        TELLOR_ORACLE_ADDRESS,
        TokenAddresses.WETH,
        STALE_PRICE_DELAY,
        **make_tx_params()
    )
