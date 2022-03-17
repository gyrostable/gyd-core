// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../../libraries/FixedPoint.sol";

contract TestingFixedPoint {
    using FixedPoint for uint256;

    function intPowDownTest(uint256 base, uint256 exp) external pure returns (uint256) {
        return base.intPowDown(exp);
    }
}
