// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../../../libraries/LogExpMath.sol";

contract LogExpMathProfiler {
    function profileSqrt(uint256[] calldata values)
        external
        pure
        returns (uint256 sqrt)
    {
        for (uint256 i = 0; i < values.length; i++) {
            LogExpMath.sqrt(values[i]);
        }

        return sqrt;
    }
}
