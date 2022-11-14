// SPDX-License-Identifier: for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>. 


pragma solidity ^0.8.4;

contract MockProtocolFeesCollector {
    function getSwapFeePercentage() external pure returns (uint256) {
        return uint256(1e18);
    }
}
