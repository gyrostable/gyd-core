// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../interfaces/IReserve.sol";

import "OpenZeppelin/openzeppelin-contracts@4.3.2/contracts/access/Ownable.sol";

/**
 * Reserve contains the logic for the Gyroscope Reserve
 */
contract Reserve is IReserve, Ownable {
    struct VaultProperties {
        address vaultAddress;
        uint256 initialVaultWeight;
        uint256 initialVaultPrice;
    }

    struct ReserveStatus {
        bool _allVaultsHealthy;
        bool _allVaultsWithinEpsilon;
        bool[] _inputVaultHealth;
        bool[] _vaultsWithinEpsilon;
    }

    /// @inheritdoc IReserve
    function depositVaultTokens(address vault, uint256 amount) external override {}

    /// @inheritdoc IReserve
    function withdrawVaultTokens(address vault, uint256 amount) external override {}
}
