// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../../../libraries/LogExpMath.sol";

contract LogExpMathProfiler {
    // NOTE: needs to not be pure to be able to get transaction information from the frontend
    function profileSqrt(uint256[] calldata values) external returns (uint256 sqrt) {
        for (uint256 i = 0; i < values.length; i++) {
            sqrt = LogExpMath.sqrt(values[i]);
        }
    }
}
