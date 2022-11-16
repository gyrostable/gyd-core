// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
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
