// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IVaultRegistry {
    event VaultRegistered(address indexed vault);
    event VaultDeregistered(address indexed vault);

    /// @notice Get the list of all vaults
    function listVaults() external view returns (address[] memory);

    /// @notice Registers a new vault
    function registerVault(address vault) external;

    /// @notice Deregister a vault
    function deregisterVault(address vault) external;
}
