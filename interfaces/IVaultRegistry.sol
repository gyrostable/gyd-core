// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "../libraries/DataTypes.sol";

interface IVaultRegistry {
    event VaultsSet(DataTypes.VaultConfiguration[] vaults);

    /// @notice Returns the metadata for the given vault
    function getVaultMetadata(address vault)
        external
        view
        returns (DataTypes.PersistedVaultMetadata memory);

    /// @notice Returns the weight of the vault given its schedule
    function getScheduleVaultWeight(address vault) external view returns (uint256);

    /// @notice Get the list of all vaults
    function listVaults() external view returns (address[] memory);

    /// @notice Registers a new vault
    function setVaults(DataTypes.VaultConfiguration[] memory vaults) external;

    /// @notice updates the vaults' flow params
    function updatePersistedVaultFlowParams(
        address[] memory vaultsToUpdate,
        uint256[] memory newShortFlowMemory,
        uint256[] memory newShortFlowThreshold
    ) external;
}
