// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./auth/Governable.sol";
import "../libraries/DataTypes.sol";
import "../libraries/FixedPoint.sol";
import "../interfaces/IVaultManager.sol";
import "../interfaces/balancer/IVault.sol";

contract ReserveSafetyManager is Ownable, Governable {
    using FixedPoint for uint256;

    uint256 maxAllowedVaultDeviation;

    constructor(uint256 initialMaxAllowedVaultDeviation) {
        maxAllowedVaultDeviation = initialMaxAllowedVaultDeviation;
    }

    function getVaultMaxDeviation() external view returns (uint256) {
        return maxAllowedVaultDeviation;
    }

    function setVaultMaxDeviation(uint256 newMaxAllowedVaultDeviation)
        external
        governanceOnly
    {
        maxAllowedVaultDeviation = newMaxAllowedVaultDeviation;
    }

    function allPoolsInVaultHealthy() internal returns (bool) {
        //Loop through all pools in one vault and return a bool if all healthy
    }

    function checkVaultsCloseToIdeal(DataTypes.VaultInfo[] memory vaults)
        internal
        view
        returns (bool, bool[] memory)
    {
        bool allVaultsWithinEpsilon = true;
        bool[] memory vaultsWithinEpsilon = new bool[](vaults.length);

        for (uint256 i = 0; i < vaults.length; i++) {
            DataTypes.VaultInfo memory vault = vaults[i];
            vaultsWithinEpsilon[i] = true;
            if (
                vault.idealWeight.absSub(vault.currentWeight) >
                maxAllowedVaultDeviation
            ) {
                allVaultsWithinEpsilon = false;
                vaultsWithinEpsilon[i] = false;
            }
        }

        return (allVaultsWithinEpsilon, vaultsWithinEpsilon);
    }

    function safeToMintOutsideEpsilon(DataTypes.VaultInfo[] memory vaults)
        internal
        pure
        returns (bool)
    {
        //Check that amount above epsilon is decreasing
        //Check that unhealthy pools have input weight below ideal weight
        //If both true, then mint
        //note: should always be able to mint at the ideal weights!

        bool anyCheckFail = false;
        for (uint256 i; i < vaults.length; i++) {
            if (!vaults[i].operatingNormally) {
                if (vaults[i].requestedWeight > vaults[i].idealWeight) {
                    anyCheckFail = true;
                    break;
                }
            }

            if (!vaults[i].withinEpsilon) {
                // check if the requested weight is closer to the ideal weight than the current weight
                uint256 distanceRequestedToIdeal = vaults[i]
                    .requestedWeight
                    .absSub(vaults[i].idealWeight);
                uint256 distanceCurrentToIdeal = vaults[i].currentWeight.absSub(
                    vaults[i].idealWeight
                );

                if (distanceRequestedToIdeal >= distanceCurrentToIdeal) {
                    anyCheckFail = true;
                    break;
                }
            }
        }

        if (!anyCheckFail) {
            return true;
        }
    }

    function anyUnhealthyVaultWouldMoveTowardsIdeal(
        DataTypes.VaultInfo[] memory vaults
    ) internal pure returns (bool) {
        bool allUnhealthyVaultsWouldMoveTowardsIdeal = true;
        for (uint256 i; i < vaults.length; i++) {
            if (!vaults[i].operatingNormally) {
                if (vaults[i].requestedWeight > vaults[i].idealWeight) {
                    allUnhealthyVaultsWouldMoveTowardsIdeal = false;
                    break;
                }
            }
        }

        if (allUnhealthyVaultsWouldMoveTowardsIdeal) {
            return true;
        }
    }
}
