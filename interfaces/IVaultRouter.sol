// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../libraries/DataTypes.sol";

/// @title IVaultRouter is used to map input tokens to the differnt vaults
/// of the Gyro reserve
interface IVaultRouter {
    /// @notice Adds a vault address to the router so it is able to route funds to it
    /// @dev This function will only be called through governance
    /// @param vaultAddress the vault address to be added
    function addVault(address vaultAddress) external;

    /// @notice Removes a vault supported by this router
    /// @dev This function will only be called through governance
    /// @param vaultAddress the vault address to be removed
    function removeVault(address vaultAddress) external;

    /// @notice Returns the list of vaults supported by the router
    /// @return the vaults supported by the router
    function supportedVaults() external view returns (address[] memory);

    /// @notice Computes the routing given the input tokens and amounts
    /// @dev Explain to a developer any extra details
    /// @param inputMonetaryAmounts the input tokens and associated amounts used to mint GYD
    /// @return a list of routes to deposit `inputTokens` and `inputAmounts`
    function computeInputRoutes(DataTypes.MonetaryAmount[] memory inputMonetaryAmounts)
        external
        view
        returns (DataTypes.TokenToVaultMapping[] memory);
}
