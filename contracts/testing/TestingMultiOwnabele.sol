// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../auth/MultiOwnable.sol";

contract TestingMultiOwnable is MultiOwnable {
    function initialize(address owner) external initializer {
        __MultiOwnable_initialize(owner);
    }
}
