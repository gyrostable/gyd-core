// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../libraries/FixedPoint.sol";

library FlowSafety {
    using FixedPoint for uint256;

    /**
     * @notice This is taken from the Balancer V1 code base.
     * Computes a**b where a is a scaled fixed-point number and b is an integer
     * The computation is performed in O(log n)
     */
    function intPowDown(uint256 base, uint256 exp) internal pure returns (uint256) {
        uint256 result = FixedPoint.ONE;

        while (exp > 0) {
            if (exp % 2 == 1) {
                result = result.mulDown(base);
            }
            exp /= 2;
            base = base.mulDown(base);
        }
        return result;
    }

    // This function calculates an exponential moving sum based on memoryParam
    function updateFlow(
        uint256 flowHistory,
        uint256 currentBlock,
        uint256 lastSeenBlock,
        uint256 memoryParam
    ) internal pure returns (uint256 updatedFlowHistory) {
        if (lastSeenBlock < currentBlock) {
            uint256 blockDifference = currentBlock - lastSeenBlock;
            uint256 memoryParamRaised = intPowDown(memoryParam, blockDifference);
            updatedFlowHistory = flowHistory.mulDown(memoryParamRaised);
        }
    }
}
