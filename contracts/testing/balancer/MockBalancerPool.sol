// SPDX-License-Identifier: for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>. 
pragma solidity ^0.8.4;

contract MockBalancerPool {
    bytes32 public immutable poolId;
    bool public pausedState;
    uint256 public pauseWindowEndTime;
    uint256 public bufferPeriodEndTime;

    uint256[] public normalizedWeights;

    constructor(bytes32 _poolId) {
        poolId = _poolId;
    }

    function getPoolId() external view returns (bytes32) {
        return poolId;
    }

    function getPausedState()
        external
        view
        returns (
            bool,
            uint256,
            uint256
        )
    {
        return (pausedState, pauseWindowEndTime, bufferPeriodEndTime);
    }

    function setPausedState(
        bool _pausedState,
        uint256 _pauseWindowEndTime,
        uint256 _bufferPeriodEndTime
    ) external {
        pausedState = _pausedState;
        pauseWindowEndTime = _pauseWindowEndTime;
        bufferPeriodEndTime = _bufferPeriodEndTime;
    }

    function setNormalizedWeights(uint256[] memory _normalizedWeights) external {
        normalizedWeights = _normalizedWeights;
    }

    function getNormalizedWeights() external view returns (uint256[] memory) {
        return normalizedWeights;
    }
}
