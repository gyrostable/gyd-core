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

    constructor(
        uint256 initialMaxAllowedVaultDeviation,
        address balancerSafetyChecksAddress
    ) {
        maxAllowedVaultDeviation = initialMaxAllowedVaultDeviation;
        balancerSafetyChecker = IBalancerSafetyChecks(
            balancerSafetyChecksAddress
        );
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

    function safeToMint(
        DataTypes.VaultInfo[] memory vaults,
        DataTypes.MintAsset[] memory mintRequests,
        bytes32[] memory poolIds,
        uint256[] memory allUnderlyingPrices
    ) internal view returns (bool mintingSafe) {
        mintingSafe = false;

        (
            bool allBalancerPoolsOperatingNormally,
            bool[] memory balancerPoolsOperatingNormally
        ) = balancerSafetyChecker.checkAllPoolsOperatingNormally(
                poolIds,
                allUnderlyingPrices
            );

        (
            bool allVaultsWithinEpsilon,
            bool[] memory vaultsWithinEpsilon
        ) = checkVaultsWithinEpsilon(vaults);

        // if check 1 succeeds and all pools healthy, then proceed with minting
        if (allBalancerPoolsOperatingNormally) {
            if (allVaultsWithinEpsilon) {
                mintingSafe = true;
            }
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

    function safeToRedeem(
        address[] memory _BPTokensOut,
        DataTypes.VaultInfo[] memory vaults
    ) internal view returns (bool) {
        bool redeemingSafe = false;
        (
            bool allVaultsWithinEpsilon,
            bool[] memory vaultsWithinEpsilon
        ) = checkVaultsWithinEpsilon(vaults);

        if (allVaultsWithinEpsilon) {
            redeemingSafe = true;
            return redeemingSafe;
        }

        // check if weights that are beyond epsilon boundary are closer to ideal than current weights
        bool checksPass = false;
        for (uint256 i; i < vaults.length; i++) {
            if (!vaults[i].withinEpsilon) {
                // check if _hypotheticalWeights[i] is closer to _idealWeights[i] than _currentWeights[i]
                uint256 distanceRequestedToIdeal = vaults[i]
                    .requestedWeight
                    .absSub(vaults[i].idealWeight);
                uint256 distanceCurrentToIdeal = vaults[i].currentWeight.absSub(
                    vaults[i].idealWeight
                );

                if (distanceRequestedToIdeal >= distanceCurrentToIdeal) {
                    checksPass = true;
                    break;
                }
            }
        }

        if (!checksPass) {
            redeemingSafe = true;
        }

        return redeemingSafe;
    }
}
