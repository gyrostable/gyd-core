// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../libraries/DataTypes.sol";

interface IVaultRegistry {
    event VaultRegistered(address indexed vault);
    event VaultDeregistered(address indexed vault);

    /// @notice Returns the metadata for the given vault
    function getVaultMetadata(address vault)
        external
        view
        returns (DataTypes.PersistedVaultMetadata memory);

    /// @notice Get the list of all vaults
    function listVaults() external view returns (address[] memory);

    /// @notice Registers a new vault
    function registerVault(
        address vault,
        uint256 initialVaultWeight,
        bytes32 underlyingPoolId
    ) external;

    /// @notice Deregister a vault
    function deregisterVault(address vault) external;
}
