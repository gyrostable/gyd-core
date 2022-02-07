from brownie import UniswapV3TwapOracleProfiler  # type: ignore
from brownie import accounts
from brownie.network import priority_fee
from scripts.profiling.profiling_utils import comput_gas_stats


def main():
    priority_fee("2 gwei")

    pools = [
        "0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8",
        "0x5777d92f208679db4b9778590fa3cab3ac9e2168",
        "0xcbcdf9626bc03e24f779434178a73a0b4bad62ed",
        "0xc63b0708e2f7e69cb8a1df0e1389a98c35a76d52",
    ]

    uniswap_v3_twap_oracle_profiler = accounts[0].deploy(UniswapV3TwapOracleProfiler)
    tx_args = {"from": accounts[0]}

    args = []
    for pool in pools:
        tx = uniswap_v3_twap_oracle_profiler.registerPool(pool, tx_args)
        asset_a = tx.events["PoolRegistered"]["assetA"]
        asset_b = tx.events["PoolRegistered"]["assetB"]
        args.append((asset_a, asset_b))
        args.append((asset_b, asset_a))

    tx = uniswap_v3_twap_oracle_profiler.profileGetRelativePrice(*zip(*args), tx_args)

    gas_stats = comput_gas_stats(tx)

    print(gas_stats["UniswapV3TwapOracle.getRelativePrice"].format_with_values(args))
