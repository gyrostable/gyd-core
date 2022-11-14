// SPDX-License-Identifier: for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>. 
pragma solidity ^0.8.4;

import "../../../libraries/Arrays.sol";

contract ArraysProfiler {
    function profileQuickSort(address[][] memory data) public returns (address[][] memory) {
        for (uint256 i = 0; i < data.length; i++) {
            Arrays.sort(data[i]);
        }
        return data;
    }

    function profileDedup(address[][] memory data) public returns (address[][] memory) {
        for (uint256 i = 0; i < data.length; i++) {
            Arrays.dedup(data[i]);
        }
        return data;
    }
}
