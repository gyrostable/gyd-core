// SPDX-License-Identifier: for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>. 
pragma solidity ^0.8.4;

/// @notice A registry of Balancer pools that are indirectly used by the Gyro Vault via the Balancer Vault.
interface IBalancerPoolRegistry {
    /// @notice Finds the Balancer pool that is used to support the underlying
    /// @param underlyingTokenAddress the underlyingToken (e.g., USDC) that will be deposited/withdrawn in/to the Gyroscope vault
    /// @return poolIds corresponding to the Balancer pool
    function getPoolIds(address underlyingTokenAddress)
        external
        view
        returns (bytes32[] memory poolIds);

    /// @notice Registers a new Balancer poolId
    /// This will be called by governance when we want to support new Balancer pools
    /// @param poolId The LP token used by the Gyroscope Vault to register
    function registerPoolId(address underlyingTokenAddress, bytes32 poolId) external;

    /// @notice Deregisters a Balancer poolId
    /// This will be called by governance when we want to stop using/supporting certain Balancer pools
    /// @param poolId The LP token used by the Gyroscope Vault to deregister
    function deregisterPoolId(address underlyingTokenAddress, bytes32 poolId) external;
}
