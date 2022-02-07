// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface IBalancerSafetyChecks {
    /// @notice Check whether Balancer pool with ID `poolId` is paused
    /// @param poolId a bytes32 Balancer poolId
    function isPoolPaused(bytes32 poolId) external view returns (bool);

    /// @notice Check whether the assets in Balancer pool with ID `poolId` have actual weights smaller
    //  than the `poolWeightMaxDeviation`. The expected weights are the NormalizedWeights.
    /// @param poolId a bytes32 Balancer poolId
    function arePoolAssetWeightsCloseToExpected(bytes32 poolId) external view returns (bool);

    /// @notice Check whether the Balancer pool with ID `poolId` is sufficiently live, where liveness is
    //  defined as the last change to the pool happening more recently than `maxActivityLag` blocks in the past.
    /// @param poolId a bytes32 Balancer poolId
    function doesPoolHaveLiveness(bytes32 poolId) external view returns (bool);

    /// @notice Check whether all stablecoins in Balancer pool with ID `poolId` are sufficiently close to the peg,
    //  where this is defined as being within `stablecoinMaxDeviation` of the peg.
    /// @param poolId a bytes32 Balancer poolId
    function areAllPoolStablecoinsCloseToPeg(bytes32 poolId) external view returns (bool);

    /// @notice Check whether all Balancer pool corresponding to IDs `poolIds` satisfy all of the sanity checks, namely:
    // 1. That each Balancer pool is sufficiently liv
    // 2. That each Balancer pool is not paused
    // 3. That the assets within each Balancer pool have weights close to the expected Weights
    // 4. That for every stabelcoin in each provided Balancer pool, the stablecoin is sufficiently close to its peg
    // If these checks are not all satisfied, the function will revert with an error.
    /// @param poolIds a bytes32 Balancer poolId
    function ensurePoolsSafe(bytes32[] memory poolIds) external;
}
