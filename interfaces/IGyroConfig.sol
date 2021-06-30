// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

/// @notice IGyroConfig stores the global configuration of the Gyroscope protocol
interface IGyroConfig {
    /// @notice Returns the current fees for minting as a percentage (with 1e18 scale)
    function getMintFee() external view returns (uint256 mintFee);
}
