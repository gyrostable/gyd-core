// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./GovernableBase.sol";

contract Governable is GovernableBase {
    constructor() {
        governor = msg.sender;
        emit GovernorChanged(address(0), msg.sender);
    }
}
