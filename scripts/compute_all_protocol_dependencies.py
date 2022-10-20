import csv
import sys
from os import path

sys.path.append(path.dirname(path.dirname(__file__)))

from misc.compute_dependencies import compute_dependencies

list_of_contracts = [
    "Governable",
    "GovernableBase",
    "GovernableUpgradeable",
    "StaticPercentageFeeHandler",
    "BalancerCEMMPriceOracle",
    "BalancerCPMMV2PriceOracle",
    "BalancerCPMMV3PriceOracle",
    "BalancerLPSharePricing",
    "BaseBalancerPriceOracle",
    "AssetRegistry",
    "BaseChainLinkOracle",
    "BaseVaultPriceOracle",
    "BatchVaultPriceOracle",
    "ChainLinkPriceOracle",
    "CheckedPriceOracle",
    "CrashProtectedChainLinkPriceOracle",
    "TrustedSignerPriceOracle",
    "UniswapV3TwapPriceOracle",
    "ReserveSafetyManager",
    "RootSafetyCheck",
    "VaultSafetyMode",
    "BalancerPoolVault",
    "BaseVault",
    "FeeBank",
    "FreezableProxy",
    "GydToken",
    "GyroConfig",
    "Motherboard",
    "PrimaryAMMV1",
    "Reserve",
    "ReserveManager",
    "VaultRegistry",
]

list_of_libraries = [
    "FullMath",
    "OracleLibrary",
    "TickMath",
    "Arrays",
    "ConfigHelpers",
    "ConfigKeys",
    "DataTypes",
    "DecimalScale",
    "EnumerableExtensions",
    "EnumerableMapping",
    "Errors",
    "FixedPoint",
    "Flow",
    "LogExpMath",
    "SignedFixedPoint",
    "StringExtensions",
    "TypeConversion",
    "Vaults",
]


def main():
    with open("all_protocol_dependencies.csv", "w", newline="") as csvfile:
        fieldnames = ["Gyro Contract", "Dependency Contract", "Path"]
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        for contract in list_of_contracts + list_of_libraries:
            dependencies = compute_dependencies(contract)
            sorted_dependencies = sorted(dependencies.items(), key=lambda v: v[1])
            for i in sorted_dependencies:
                writer.writerow(
                    {
                        "Gyro Contract": contract,
                        "Dependency Contract": i[0],
                        "Path": i[1],
                    }
                )


if __name__ == "__main__":
    main()
