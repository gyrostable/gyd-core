// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

contract MockBalancerPool {
    bytes32 public immutable poolId;
    bool public pausedState;
    uint256 public pauseWindowEndTime;
    uint256 public bufferPeriodEndTime;


    constructor(
        bytes32 _poolId     
    ) {
        poolId = _poolId;
    }

    function getPoolId() external view returns (bytes32) {
        return poolId;
    }

    function getPausedState() external view returns (bool, uint256, uint256) {
        return  (pausedState, pauseWindowEndTime, bufferPeriodEndTime);
    }

    function setPausedState(bool _pausedState,
                            uint256 _pauseWindowEndTime,
                            uint256 _bufferPeriodEndTime) external {
        pausedState = _pausedState;
        pauseWindowEndTime = _pauseWindowEndTime;
        bufferPeriodEndTime = _bufferPeriodEndTime;
    }

}