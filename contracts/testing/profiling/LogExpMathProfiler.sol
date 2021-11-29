// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../../libraries/LogExpMath.sol";

contract LogExpMathProfiler {
    function profileSqrt(uint256[] calldata values) external returns (uint256) {
        for (uint256 i = 0; i < values.length; i++) {
            LogExpMath.sqrt(values[i]);
        }
    }
}
