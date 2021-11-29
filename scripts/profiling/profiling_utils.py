import statistics
from collections import defaultdict
from dataclasses import dataclass
from sys import intern
from typing import Dict, List, Tuple

from brownie.network.transaction import _step_compare


def _format_tuple(info, meta, unscale=True):
    if unscale:
        meta = round(meta / 10 ** 18, 3)
    return f"{info} ({meta})"


@dataclass
class CallStats:
    REPR_KEYS = [
        "mean_internal_gas",
        "median_internal_gas",
        "std_internal_gas",
        "min_internal_gas",
        "max_internal_gas",
    ]

    calls: List[dict]

    @property
    def mean_internal_gas(self):
        return statistics.mean([x["internal_gas"] for x in self.calls])

    @property
    def median_internal_gas(self):
        return statistics.median([x["internal_gas"] for x in self.calls])

    @property
    def std_internal_gas(self):
        if len(self.calls) == 1:
            return 0
        return statistics.stdev([x["internal_gas"] for x in self.calls])

    @property
    def min_internal_gas(self):
        return min([x["internal_gas"] for x in self.calls])

    @property
    def max_internal_gas(self):
        return max([x["internal_gas"] for x in self.calls])

    @property
    def mean_total_gas(self):
        return statistics.mean([x["total_gas"] for x in self.calls])

    @property
    def median_total_gas(self):
        return statistics.median([x["total_gas"] for x in self.calls])

    @property
    def std_total_gas(self):
        if len(self.calls) == 1:
            return 0
        return statistics.stdev([x["total_gas"] for x in self.calls])

    @property
    def min_total_gas(self):
        return min([x["total_gas"] for x in self.calls])

    @property
    def max_total_gas(self):
        return max([x["total_gas"] for x in self.calls])

    def _format(self, min_gas=None, max_gas=None):
        result = ""
        for key in self.REPR_KEYS:
            key_norm = key.replace("_", " ").replace("internal ", "")
            value = round(getattr(self, key), 3)
            if key == "min_internal_gas" and min_gas:
                value = min_gas
            if key == "max_internal_gas" and max_gas:
                value = max_gas
            result += f"{key_norm}: {value}\n"
        return result

    def __repr__(self) -> str:
        return self._format()

    def min_max_with_values(self, values) -> Tuple[Tuple[int, int], Tuple[int, int]]:
        internal_gases = [x["internal_gas"] for x in self.calls]
        min_gas = min(internal_gases)
        min_gas_index = internal_gases.index(min_gas)
        max_gas = max(internal_gases)
        max_gas_index = internal_gases.index(max_gas)
        return ((min_gas, values[min_gas_index]), (max_gas, values[max_gas_index]))

    def format_with_values(self, values, unscale=True) -> str:
        min_gas, max_gas = self.min_max_with_values(values)
        return self._format(_format_tuple(*min_gas), _format_tuple(*max_gas, unscale))


def comput_gas_stats(tx) -> Dict[str, CallStats]:
    """
    Display the complete sequence of contracts and methods called during
    the transaction. The format:
    Contract.functionName  [instruction]  start:stop  [gas used]
    * start:stop are index values for the `trace` member of this object,
        showing the points where the call begins and ends
    * for calls that include subcalls, gas use is displayed as
        [gas used in this frame / gas used in this frame + subcalls]
    * Calls displayed in red ended with a `REVERT` or `INVALID` instruction.
    Arguments
    ---------
    expand : bool
        If `True`, show an expanded call trace including inputs and return values
    """

    results = defaultdict(list)

    trace = tx.trace
    fn = trace[0]["fn"]
    total_gas, internal_gas = tx._get_trace_gas(0, len(tx.trace))
    results[fn].append({"total_gas": total_gas, "internal_gas": internal_gas})
    key = {"fn": fn, "total_gas": total_gas, "internal_gas": internal_gas}
    # key = _step_internal(
    #     trace[0], trace[-1], 0, len(trace), tx._get_trace_gas(0, len(tx.trace))
    # )

    call_tree: List = [[key]]
    active_tree: List = [call_tree[0]]

    # (index, depth, jumpDepth) for relevent steps in the trace
    trace_index = [(0, 0, 0)] + [
        (i, trace[i]["depth"], trace[i]["jumpDepth"])
        for i in range(1, len(trace))
        if not _step_compare(trace[i], trace[i - 1])
    ]  # type: ignore

    subcalls = tx.subcalls[::-1]
    for i, (idx, depth, jump_depth) in enumerate(trace_index[1:], start=1):
        last = trace_index[i - 1]
        if depth == last[1] and jump_depth < last[2]:
            # returning from an internal function, reduce tree by one
            active_tree.pop()
            continue
        elif depth < last[1]:
            # returning from an external call, return tree by jumpDepth of the previous depth
            active_tree = active_tree[: -(last[2] + 1)]
            continue

        if depth > last[1]:
            # called to a new contract
            end = next((x[0] for x in trace_index[i + 1 :] if x[1] < depth), len(trace))
            total_gas, internal_gas = tx._get_trace_gas(idx, end)
            fn = trace[idx]["fn"]
            key = {"fn": fn, "total_gas": total_gas, "internal_gas": internal_gas}
            results[fn].append({"total_gas": total_gas, "internal_gas": internal_gas})
        elif depth == last[1] and jump_depth > last[2]:
            # jumped into an internal function
            end = next(
                (
                    x[0]
                    for x in trace_index[i + 1 :]
                    if x[1] < depth or (x[1] == depth and x[2] < jump_depth)
                ),
                len(trace),
            )

            total_gas, internal_gas = tx._get_trace_gas(idx, end)
            fn = trace[idx]["fn"]

            key = {"fn": fn, "total_gas": total_gas, "internal_gas": internal_gas}
            results[fn].append({"total_gas": total_gas, "internal_gas": internal_gas})
            # key = _step_internal(
            #     trace[idx], trace[end - 1], idx, end, (total_gas, internal_gas)
            # )

        active_tree[-1].append([key])
        active_tree.append(active_tree[-1][-1])

    return {fn: CallStats(calls) for fn, calls in results.items()}
