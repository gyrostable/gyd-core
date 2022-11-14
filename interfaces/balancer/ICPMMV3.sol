// SPDX-License-Identifier: for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>. 
pragma solidity ^0.8.4;

import "./IMinimalPoolView.sol";

interface ICPMMV3 is IMinimalPoolView {
    function getRoot3Alpha() external view returns (uint256);
}
