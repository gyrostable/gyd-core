from brownie import accounts
from brownie import LogExpMathProfiler  # type: ignore

from tests.support.utils import scale
from scripts.profiling.profiling_utils import comput_gas_stats


def main():
    log_exp_math_profiler = accounts[0].deploy(LogExpMathProfiler)
    args = [
        scale("0"),
        scale("0.1"),
        scale("0.5"),
        scale("1.0"),
        scale("1.5"),
        scale("2"),
        scale("3"),
        scale("5"),
        scale("10"),
        scale("50"),
        scale("100"),
        scale("500"),
    ]
    tx = log_exp_math_profiler.profileSqrt(args)

    gas_stats = comput_gas_stats(tx)

    print(
        gas_stats["LogExpMath.sqrt"].format_with_values(args, minmax=True, unscale=True)
    )
