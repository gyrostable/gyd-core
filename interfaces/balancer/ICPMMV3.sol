// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./IMinimalPoolView.sol";

interface ICPMMV3 is IMinimalPoolView {
    function getRoot3Alpha() external view returns (uint256);
}
