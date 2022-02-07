// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./auth/Governable.sol";
import "../libraries/DataTypes.sol";
import "../libraries/FixedPoint.sol";
import "../interfaces/IVaultManager.sol";
import "../interfaces/IBalancerSafetyChecks.sol";
import "../interfaces/balancer/IVault.sol";

contract ReserveSafetyManager is Ownable, Governable {
    using FixedPoint for uint256;

    uint256 maxAllowedVaultDeviation;

    IBalancerSafetyChecks balancerSafetyChecker;

    constructor(uint256 initialMaxAllowedVaultDeviation, address balancerSafetyChecksAddress) {
        maxAllowedVaultDeviation = initialMaxAllowedVaultDeviation;
        balancerSafetyChecker = IBalancerSafetyChecks(balancerSafetyChecksAddress);
    }

    function getVaultMaxDeviation() external view returns (uint256) {
        return maxAllowedVaultDeviation;
    }

    function setVaultMaxDeviation(uint256 newMaxAllowedVaultDeviation) external governanceOnly {
        maxAllowedVaultDeviation = newMaxAllowedVaultDeviation;
    }

    function allPoolsInVaultHealthy() internal returns (bool) {
        //Loop through all pools in one vault and return a bool if all healthy
    }

    function isVaultSafeToMint(DataTypes.VaultInfo memory vault) internal view returns (bool) {
        bool weightWithinEpsilon = vault.idealWeight.absSub(vault.requestedWeight) <=
            maxAllowedVaultDeviation;
        bool weightImproving = vault.idealWeight.absSub(vault.requestedWeight) <
            vault.idealWeight.absSub(vault.currentWeight);
        return weightWithinEpsilon || weightImproving;
    }

    function areAllVaultsSafeToMint(DataTypes.VaultInfo[] memory vaults)
        internal
        view
        returns (bool result, bool[] memory vaultsSafety)
    {
        vaultsSafety = new bool[](vaults.length);
        for (uint256 i = 0; i < vaults.length; i++) {
            vaultsSafety[i] = isVaultSafeToMint(vaults[i]);
            result = result && vaultsSafety[i];
        }
    }

    function checkVaultsWithinEpsilon(DataTypes.VaultInfo[] memory vaults)
        internal
        view
        returns (bool, bool[] memory)
    {
        bool allVaultsWithinEpsilon = true;
        bool[] memory vaultsWithinEpsilon = new bool[](vaults.length);

        for (uint256 i = 0; i < vaults.length; i++) {
            DataTypes.VaultInfo memory vault = vaults[i];
            vaultsWithinEpsilon[i] = true;
            if (vault.idealWeight.absSub(vault.currentWeight) > maxAllowedVaultDeviation) {
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
        //If both true, then mintingSafe
        //note: should always be able to mintingSafe at the ideal weights!

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
                uint256 distanceRequestedToIdeal = vaults[i].requestedWeight.absSub(
                    vaults[i].idealWeight
                );
                uint256 distanceCurrentToIdeal = vaults[i].currentWeight.absSub(
                    vaults[i].idealWeight
                );

                if (distanceRequestedToIdeal >= distanceCurrentToIdeal) {
                    anyCheckFail = true;
                    break;
                }
            }
        }

        return !anyCheckFail;
    }

    function anyUnhealthyVaultWouldMoveTowardsIdeal(DataTypes.VaultInfo[] memory vaults)
        internal
        pure
        returns (bool)
    {
        bool allUnhealthyVaultsWouldMoveTowardsIdeal = true;
        for (uint256 i; i < vaults.length; i++) {
            if (!vaults[i].operatingNormally) {
                if (vaults[i].requestedWeight > vaults[i].idealWeight) {
                    allUnhealthyVaultsWouldMoveTowardsIdeal = false;
                    break;
                }
            }
        }

        return allUnhealthyVaultsWouldMoveTowardsIdeal;
    }

    function isVaultPaused(DataTypes.VaultInfo memory vault) internal pure returns (bool) {
        //To implement
    }

    function safeToMint(
        DataTypes.VaultInfo[] memory vaults,
        DataTypes.MintAsset[] memory,
        bytes32[] memory poolIds
    ) internal returns (bool mintingSafe) {
        mintingSafe = false;

        balancerSafetyChecker.ensurePoolsSafe(poolIds);

        (bool allVaultsWithinEpsilon, ) = checkVaultsWithinEpsilon(vaults);

        // if check 1 succeeds and all pools healthy, then proceed with minting
        // if (allBalancerPoolsOperatingNormally) {
        if (allVaultsWithinEpsilon) {
            mintingSafe = true;
            // }
        } else {
            //Check that unhealthy pools have input weight below ideal weight. If true, mintingSafe
            if (allVaultsWithinEpsilon) {
                mintingSafe = anyUnhealthyVaultWouldMoveTowardsIdeal(vaults);
            }
            //Outside of the epsilon boundary
            else {
                mintingSafe = safeToMintOutsideEpsilon(vaults);
            }
        }

        return mintingSafe;
    }

    function safeToRedeem(address[] memory, DataTypes.VaultInfo[] memory vaults)
        internal
        view
        returns (bool)
    {
        (bool allVaultsWithinEpsilon, ) = checkVaultsWithinEpsilon(vaults);

        if (allVaultsWithinEpsilon) {
            return true;
        }

        // check if weights that are beyond epsilon boundary are closer to ideal than current weights
        bool checksPass = false;
        for (uint256 i; i < vaults.length; i++) {
            if (!vaults[i].withinEpsilon) {
                // check if _hypotheticalWeights[i] is closer to _idealWeights[i] than _currentWeights[i]
                uint256 distanceRequestedToIdeal = vaults[i].requestedWeight.absSub(
                    vaults[i].idealWeight
                );
                uint256 distanceCurrentToIdeal = vaults[i].currentWeight.absSub(
                    vaults[i].idealWeight
                );

                if (distanceRequestedToIdeal >= distanceCurrentToIdeal) {
                    checksPass = true;
                    break;
                }
            }
        }

        return !checksPass;
    }
}
