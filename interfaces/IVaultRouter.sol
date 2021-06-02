// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

/// @title IVaultRouter is used to map input tokens to the differnt vaults
/// of the Gyro reserve
interface IVaultRouter {
    struct Route {
        address token;
        uint256 amount;
        address vaultAddress;
    }

    /// @notice Adds a vault address to the router so it is able to route funds to it
    /// @dev This function will only be called through governance
    /// @param _vaultAddress the vault address to be added
    function addVault(address _vaultAddress) external;

    /// @notice Removes a vault supported by this router
    /// @dev This function will only be called through governance
    /// @param _vaultAddress the vault address to be removed
    function removeVault(address _vaultAddress) external;

    /// @notice Returns the list of vaults supported by the router
    /// @return the vaults supported by the router
    function supportedVaults() external returns (address[] memory);

    /// @notice Computes the routing given the input tokens and amounts
    /// @dev Explain to a developer any extra details
    /// @param inputTokens the input tokens used to mint GYD
    /// @param inputAmounts the amounts of each tokens, should be the same length as `tokens`
    /// @return a list of routes to deposit `inputTokens` and `inputAmounts`
    function computeInputRoutes(
        address[] memory inputTokens,
        uint256[] memory inputAmounts
    ) external returns (Route[] memory);
}
