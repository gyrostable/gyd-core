// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface IBalancerSafetyChecks {
    /// @notice Check that Balancer Poolids provided are operating normally
    /// @param poolIds the poolIds to check for normal operation
    /// @param allUnderlyingPrices current asset prices
    function checkAllPoolsOperatingNormally(
        bytes32[] memory poolIds,
        uint256[] memory allUnderlyingPrices
    ) external view returns (bool, bool[] memory);
}
