// SPDX-License-Identifier: for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>. 
pragma solidity ^0.8.4;

import "./GovernableBase.sol";

contract Governable is GovernableBase {
    constructor() {
        governor = msg.sender;
        emit GovernorChanged(address(0), msg.sender);
    }
}
