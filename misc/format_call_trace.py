import argparse
from dataclasses import dataclass
import gzip
import json
from functools import cached_property
from glob import glob
from os import path
from typing import Dict, List, Optional

from web3 import Web3


ROOT_DIR = path.dirname(path.dirname(__file__))

DEFAULT_NETWORK_ID = 137
TRACE_URLS = {
    137: "https://polygonscan.com/vmtrace",
    1: "https://etherscan.io/vmtrace",
}

parser = argparse.ArgumentParser(prog="format-call-trace.py")
parser.add_argument("trace_or_txid", help="Path to the trace file or transaction id")
parser.add_argument("-s", "--save-trace", help="Save trace to file when it is fetched")
parser.add_argument(
    "-n", "--network", help="Network ID", type=int, default=DEFAULT_NETWORK_ID
)


@dataclass
class Metadata:
    selectors: Dict[str, str]
    known_contracts: Dict[str, str]


def load_4bytes():
    files = [
        "build/4byte_signatures.json",
        "misc/vaults_4byte.json",
        "misc/vaults_4byte.json",
    ]
    selectors = {}
    for filename in files:
        open_f = gzip.open if filename.endswith(".gz") else open
        with open_f(path.join(ROOT_DIR, filename)) as f:
            selectors.update(json.load(f))
    return selectors


def load_known_contracts(network_id):
    with open(path.join(ROOT_DIR, "misc/known_contracts.json")) as f:
        known_contracts = {
            str(Web3.toChecksumAddress(a)): n
            for a, n in json.load(f)[str(network_id)].items()
        }

    for deployment in glob(
        path.join(ROOT_DIR, f"build/deployments/{network_id}/*.json")
    ):
        with open(deployment) as f:
            deployment = json.load(f)
            key = Web3.toChecksumAddress(deployment["deployment"]["address"])
            known_contracts[str(key)] = deployment["contractName"]
    return known_contracts


class Call:
    metadata: Metadata

    def __init__(self, trace, parent=None):
        self.trace = trace
        self.calls = [Call(call, self) for call in trace.get("calls", [])]
        self.parent = parent

    @cached_property
    def input(self):
        return self.trace["input"]

    @cached_property
    def error(self):
        return self.trace.get("error")

    @cached_property
    def selector(self):
        return self.input[2:10]

    @cached_property
    def function_signature(self):
        return self.metadata.selectors.get(self.selector, self.selector)

    @cached_property
    def function_name(self):
        return self.function_signature.split("(")[0]

    @cached_property
    def to(self):
        return Web3.toChecksumAddress(self.trace["to"])

    @cached_property
    def type(self):
        return self.trace["type"]

    @cached_property
    def is_proxy(self):
        return (
            self.to in self.metadata.known_contracts
            and len(self.calls) == 1
            and self.calls[0].type == "DELEGATECALL"
            and self.calls[0].input == self.input
        )

    @cached_property
    def formatted_to(self):
        name = self.metadata.known_contracts.get(self.to)
        if not name:
            if self.parent and self.parent.is_proxy:
                return self.metadata.known_contracts.get(self.parent.to, self.to)
            return self.to
        if self.is_proxy:
            return f"{name}Proxy"
        return name

    @cached_property
    def gas_used(self):
        return int(self.trace["gasUsed"], 16)

    @cached_property
    def summary(self):
        summary = f"{self.formatted_to}.{self.function_name} ({self.gas_used:,})"
        if self.error:
            summary += f" ✗: {self.error}"
        return summary

    def format(self, maxlvl=None):
        return self._format([], maxlvl=maxlvl)

    def _format(
        self,
        prefixes: List[bool],
        is_last: bool = False,
        maxlvl=None,
        lvl=1,
    ):
        format_prefix = lambda x: "│   " if x else "    "
        prefix = "".join(map(format_prefix, prefixes[:-1]))
        pipe = "└" if is_last else "│"
        prefix += f"{pipe}─({self.type})─"
        line = f"{prefix} {self.summary}\n"
        if maxlvl is None or lvl < maxlvl:
            line += "".join(
                child._format(
                    prefixes + [i < len(self.calls) - 1],
                    i == len(self.calls) - 1,
                    maxlvl,
                    lvl + 1,
                )
                for i, child in enumerate(self.calls)
            )
        return line


def get_trace(trace_or_txid: str, network_id: int, save_trace: Optional[str] = None):
    if path.exists(trace_or_txid):
        with open(trace_or_txid) as f:
            return json.load(f)
    elif trace_or_txid.startswith("0x") and len(trace_or_txid) == 66:
        from bs4 import BeautifulSoup
        import requests

        base_url = TRACE_URLS[network_id]
        r = requests.get(f"{base_url}?txhash={trace_or_txid}&type=gethtrace2")
        if r.status_code != 200:
            raise ValueError("could not get trace")
        soup = BeautifulSoup(r.text, "html.parser")
        result = json.loads(soup.find(id="editor").text)
        if save_trace:
            with open(save_trace, "w") as f:
                json.dump(result, f)
        return result
    else:
        raise ValueError("invalid trace or txid")


def main():
    args = parser.parse_args()
    trace = get_trace(args.trace_or_txid, args.network, save_trace=args.save_trace)
    Call.metadata = Metadata(load_4bytes(), load_known_contracts(args.network))
    call = Call(trace)
    print(call.format())


if __name__ == "__main__":
    main()
