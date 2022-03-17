import random
from brownie import accounts
from brownie import ArraysProfiler  # type: ignore

from scripts.profiling.profiling_utils import comput_gas_stats


def main():
    random.seed(0)

    arrays_profiler = accounts[0].deploy(ArraysProfiler)
    for n in range(5, 15):
        print(f"n = {n}")

        args = []
        for _ in range(10):
            arr = []
            for i in range(n):
                arr.extend(["0x" + i.to_bytes(20, "big").hex()] * random.randint(0, 4))
            arr = arr[:n]
            args.append(arr)

        tx = arrays_profiler.profileDedup(args)
        gas_stats = comput_gas_stats(tx)
        print(gas_stats["Arrays.dedup"].format_with_values(args, minmax=True))

        print()
