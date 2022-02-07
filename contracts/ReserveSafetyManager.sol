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
import "../libraries/Errors.sol";

contract ReserveSafetyChecks is Ownable, Governable {
    using FixedPoint for uint256;

    uint256 private maxAllowedVaultDeviation;
    address public balancerSafetyChecks;

    constructor(uint256 _maxAllowedVaultDeviation, address _balancerSafetyChecks) {
        maxAllowedVaultDeviation = _maxAllowedVaultDeviation;
        balancerSafetyChecks = _balancerSafetyChecks;
    }

    function getVaultMaxDeviation() external view returns (uint256) {
        return maxAllowedVaultDeviation;
    }

    function setVaultMaxDeviation(uint256 _maxAllowedVaultDeviation) external governanceOnly {
        maxAllowedVaultDeviation = _maxAllowedVaultDeviation;
    }

    function isVaultPaused(DataTypes.VaultInfo memory vault) external view returns (bool) {
        return vault.isPaused;
    }

    function wouldVaultsRemainBalanced(DataTypes.VaultInfo[] memory vaults)
        internal
        view
        returns (bool)
    {
        for (uint256 i = 0; i < vaults.length; i++) {
            bool balanced = vaults[i].idealWeight.absSub(vaults[i].requestedWeight) <=
                maxAllowedVaultDeviation;
            if (!balanced) {
                return false;
            }
        }
        return true;
    }

    function wouldVaultsBeRebalancing(DataTypes.VaultInfo[] memory vaults)
        internal
        view
        returns (bool)
    {
        for (uint256 i = 0; i < vaults.length; i++) {
            bool rebalancing = vaults[i].idealWeight.absSub(vaults[i].requestedWeight) <
                vaults[i].idealWeight.absSub(vaults[i].currentWeight);
            if (!rebalancing) {
                return false;
            }
        }
        return true;
    }

    function safeToMint(DataTypes.VaultInfo[] memory vaults, bytes32[] memory poolIds)
        public
        returns (bool)
    {
        IBalancerSafetyChecks balancerSafetyChecksModule = IBalancerSafetyChecks(
            balancerSafetyChecks
        );

        balancerSafetyChecksModule.ensurePoolsSafe(poolIds);

        if (wouldVaultsRemainBalanced(vaults)) {
            return true;
        } else if (wouldVaultsBeRebalancing(vaults)) {
            return true;
        } else {
            return false;
        }
    }
}
