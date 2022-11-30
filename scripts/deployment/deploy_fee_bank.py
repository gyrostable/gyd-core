from brownie import FeeBank, GyroConfig  # type: ignore
from scripts.utils import (
    as_singleton,
    deploy_proxy,
    get_deployer,
    make_tx_params,
    with_deployed,
    with_gas_usage,
)
from tests.support import config_keys


@with_gas_usage
@with_deployed(FeeBank)
def proxy(fee_bank):
    deploy_proxy(
        fee_bank,
        config_key=config_keys.FEE_BANK_ADDRESS,
        init_data=fee_bank.initialize.encode_input(get_deployer()),
    )


@with_gas_usage
@as_singleton(FeeBank)
def main():
    deployer = get_deployer()
    deployer.deploy(FeeBank, **make_tx_params())
