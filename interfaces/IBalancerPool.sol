// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "./../libraries/DataTypes.sol";

/// @title IBalancerPool is the boiler plate wrapper for Balancer Pools
interface IBalancerPool {
    /// @notice Returns the current paused state of a Balancer pool
    function getPausedState()
        external
        view
        returns (
            bool paused,
            uint256 pauseWindowEndTime,
            uint256 bufferPeriodEndTime
        );

    function getPoolId() external view returns (bytes32);

    /// @notice Returns the normalized weights of a pool, in the same order as the pool tokens
    function getNormalizedWeights() external view returns (uint256[] memory);
}
