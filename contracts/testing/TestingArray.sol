// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "../../libraries/Arrays.sol";

contract TestingArray {
    function sort(address[] memory data) external view returns (address[] memory) {
        return Arrays.sort(data);
    }

    function dedup(address[] memory data) external pure returns (address[] memory) {
        return Arrays.dedup(data);
    }
}
