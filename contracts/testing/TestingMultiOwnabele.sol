// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "../auth/MultiOwnable.sol";

contract TestingMultiOwnable is MultiOwnable {
    function initialize(address owner) external initializer {
        __MultiOwnable_initialize(owner);
    }
}
