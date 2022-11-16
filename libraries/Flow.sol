// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "./FixedPoint.sol";

library Flow {
    using FixedPoint for uint256;

    // This function calculates an exponential moving sum based on memoryParam
    function updateFlow(
        uint256 flowHistory,
        uint256 currentBlock,
        uint256 lastSeenBlock,
        uint256 memoryParam
    ) internal pure returns (uint256) {
        if (lastSeenBlock < currentBlock) {
            uint256 blockDifference = currentBlock - lastSeenBlock;
            uint256 memoryParamRaised = memoryParam.intPowDown(blockDifference);
            return flowHistory.mulDown(memoryParamRaised);
        } else if (lastSeenBlock == currentBlock) {
            return flowHistory;
        }
        revert(Errors.INVALID_ARGUMENT);
    }
}
