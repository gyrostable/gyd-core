from brownie import CompoundV2RateProvider  # type: ignore

from scripts.utils import get_deployer, make_tx_params
from tests.fixtures.mainnet_contracts import TokenAddresses


def main(token):
    deployer = get_deployer()
    token_address = getattr(TokenAddresses, token)
    deployer.deploy(
        CompoundV2RateProvider, token_address, **make_tx_params(), publish_source=True
    )
