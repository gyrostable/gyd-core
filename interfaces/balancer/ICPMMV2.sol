// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./IMinimalPoolView.sol";

interface ICPMMV2 is IMinimalPoolView {
    function getSqrtParameters() external view returns (uint256, uint256);
}
