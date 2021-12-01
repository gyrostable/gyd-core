// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../libraries/DataTypes.sol";
import "../libraries/FixedPoint.sol";
import "../interfaces/IVaultManager.sol";
import "../interfaces/balancer/IVault.sol";

contract ReserveSafetyChecks is Ownable {
    using FixedPoint for uint256;

    uint256 private portfolioWeightEpsilon;

    IVaultManager vaultManager;

    function allPoolsInVaultHealthy() internal returns (bool) {
        //Loop through all pools in one vault and return a bool if all healthy
    }

    // function computeCurrentVaultWeights() external {}

    function checkVaultsWithinEpsilon(DataTypes.VaultInfo[] memory vaults)
        external
        view
        returns (bool, bool[] memory)
    {
        bool allVaultsWithinEpsilon = true;
        bool[] memory vaultsWithinEpsilon = new bool[](vaults.length);

        for (uint256 i = 0; i < vaults.length; i++) {
            DataTypes.VaultInfo memory vault = vaults[i];
            vaultsWithinEpsilon[i] = true;
            if (vault.idealWeight.absSub(vault.currentWeight) > portfolioWeightEpsilon) {
                allVaultsWithinEpsilon = false;
                vaultsWithinEpsilon[i] = false;
            }
        }

        return (allVaultsWithinEpsilon, vaultsWithinEpsilon);
    }

    function checkVaultsWithinEpsilon(DataTypes.Reserve memory reserve)
        internal
        view
        returns (bool, bool[] memory)
    {
        bool _allVaultsWithinEpsilon = true;

        bool[] memory _vaultsWithinEpsilon = new bool[](reserve.vaultAddresses.length);

        for (uint256 i = 0; i < reserve.vaultAddresses.length; i++) {
            _vaultsWithinEpsilon[i] = true;
            if (
                reserve.hypotheticalVaultWeights[i] >=
                reserve.idealVaultWeights[i] + portfolioWeightEpsilon
            ) {
                _allVaultsWithinEpsilon = false;
                _vaultsWithinEpsilon[i] = false;
            } else if (
                reserve.hypotheticalVaultWeights[i] + portfolioWeightEpsilon <=
                reserve.idealVaultWeights[i]
            ) {
                _allVaultsWithinEpsilon = false;
                _vaultsWithinEpsilon[i] = false;
            }
        }

        return (_allVaultsWithinEpsilon, _vaultsWithinEpsilon);
    }

    function safeToMintOutsideEpsilon(DataTypes.Reserve memory reserve)
        internal
        pure
        returns (bool _anyCheckFail)
    {
        //Check that amount above epsilon is decreasing
        //Check that unhealthy pools have input weight below ideal weight
        //If both true, then mint
        //note: should always be able to mint at the ideal weights!
        _anyCheckFail = false;
        for (uint256 i; i < reserve.vaultAddresses.length; i++) {
            if (!reserve.vaultHealth[i]) {
                if (reserve.inputVaultWeights[i] > reserve.idealVaultWeights[i]) {
                    _anyCheckFail = true;
                    break;
                }
            }

            if (!reserve.vaultsWithinEpsilon[i]) {
                // check if _hypotheticalWeights[i] is closer to _idealWeights[i] than _currentWeights[i]
                uint256 _distanceHypotheticalToIdeal = reserve.hypotheticalVaultWeights[i].absSub(
                    reserve.idealVaultWeights[i]
                );
                uint256 _distanceCurrentToIdeal = reserve.currentVaultWeights[i].absSub(
                    reserve.idealVaultWeights[i]
                );

                if (_distanceHypotheticalToIdeal >= _distanceCurrentToIdeal) {
                    _anyCheckFail = true;
                    break;
                }
            }
        }

        if (!_anyCheckFail) {
            return true;
        }
    }

    function checkUnhealthyMovesToIdeal(DataTypes.Reserve memory reserve)
        internal
        pure
        returns (bool _launch)
    {
        bool _unhealthyMovesTowardIdeal = true;
        for (uint256 i; i < reserve.vaultAddresses.length; i++) {
            if (!reserve.vaultHealth[i]) {
                if (reserve.inputVaultWeights[i] > reserve.idealVaultWeights[i]) {
                    _unhealthyMovesTowardIdeal = false;
                    break;
                }
            }
        }

        if (_unhealthyMovesTowardIdeal) {
            _launch = true;
        }
    }
}
