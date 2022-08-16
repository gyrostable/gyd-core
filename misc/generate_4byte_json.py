import glob
import json
from os import path

import argparse

import web3

BUILD_PATH = path.join(path.dirname(path.dirname(__file__)), "build")
CONTRACTS_PATH = path.join(BUILD_PATH, "contracts")
DEFAULT_OUTPUT = path.join(BUILD_PATH, "4byte_signatures.json")

parser = argparse.ArgumentParser(prog="generate_4byte_json")
parser.add_argument("--output", "-o", type=str, default=DEFAULT_OUTPUT)
parser.add_argument("--include-contract-name", "-i", action="store_true")


def encode_argument(component):
    if component["type"] == "tuple":
        return "(" + encode_arguments(component["components"]) + ")"
    return component["type"]


def encode_arguments(components):
    return ",".join([encode_argument(component) for component in components])


def encode_function(func_abi):
    return func_abi["name"] + "(" + encode_arguments(func_abi["inputs"]) + ")"


def generate_abi_signatures(contract_data, include_contract_name=False):
    signatures = {}
    if "Mock" in contract_data["contractName"] and include_contract_name:
        return []
    for func in contract_data["abi"]:
        if func["type"] != "function":
            continue
        signature = encode_function(func)
        selector = web3.Web3.keccak(text=signature)[:4].hex()[2:]
        if include_contract_name:
            signature = contract_data["contractName"] + "." + signature
        signatures[selector] = signature
    return signatures


def generate_all_signatures(files, include_contract_name=False):
    signatures = {}
    for contract in files:
        with open(contract) as f:
            contract_data = json.load(f)
            signatures.update(
                generate_abi_signatures(
                    contract_data, include_contract_name=include_contract_name
                )
            )
    return signatures


def run_generation(output, include_contract_name):
    files = glob.glob(path.join(CONTRACTS_PATH, "**", "*.json"), recursive=True)
    signatures = generate_all_signatures(
        files, include_contract_name=include_contract_name
    )
    with open(output, "w") as f:
        json.dump(signatures, f, indent=2)


def main():
    args = parser.parse_args()
    run_generation(args.output, args.include_contract_name)


if __name__ == "__main__":
    main()
