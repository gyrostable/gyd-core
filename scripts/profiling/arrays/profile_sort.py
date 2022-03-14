import random
from brownie import accounts
from brownie import ArraysProfiler  # type: ignore

from scripts.profiling.profiling_utils import comput_gas_stats


def main():
    random.seed(0)

    arrays_profiler = accounts[0].deploy(ArraysProfiler)
    for n in range(5, 15):
        print(f"n = {n}")

        args = [
            ["0x" + random.randint(0, 100).to_bytes(20, "big").hex() for _ in range(n)]
            for _ in range(10)
        ]

        tx = arrays_profiler.profileQuickSort(args)
        gas_stats = comput_gas_stats(tx)
        print(gas_stats["Arrays.sort"].format_with_values(args, minmax=True))

        print()
