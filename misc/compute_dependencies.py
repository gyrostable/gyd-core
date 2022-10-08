import argparse
import json
from os import path
from typing import Dict

BUILD_DIR = path.join(path.dirname(path.dirname(__file__)), "build")

parser = argparse.ArgumentParser(prog="compute-dependencies")
parser.add_argument("contract", help="Contract name for which to get dependencies")


def get_build_info(contract_name: str):
    contract_path = path.join(BUILD_DIR, "contracts", f"{contract_name}.json")
    if not path.exists(contract_path):
        contract_path = path.join(BUILD_DIR, "interfaces", f"{contract_name}.json")
    with open(contract_path) as f:
        return json.load(f)


def compute_dependencies(target_name: str):
    def _compute(contract_name: str, dependencies: Dict[str, str]):
        if contract_name in dependencies:
            return dependencies

        build_info = get_build_info(contract_name)

        if contract_name != target_name:
            dependencies[contract_name] = build_info["ast"]["absolutePath"]

        for dependency in build_info["dependencies"]:
            dependencies.update(_compute(dependency, dependencies))
        return dependencies

    return _compute(target_name, {})


def main():
    args = parser.parse_args()
    dependencies = compute_dependencies(args.contract)
    sorted_dependencies = sorted(dependencies.items(), key=lambda v: v[1])
    for contract_name, contract_path in sorted_dependencies:
        print(contract_name, contract_path, sep=": ")


if __name__ == "__main__":
    main()
