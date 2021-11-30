// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../../libraries/Errors.sol";

contract Governable {
    event GovernorChanged(address oldGovernor, address newGovernor);

    address public governor;

    constructor() {
        governor = msg.sender;
        emit GovernorChanged(address(0), msg.sender);
    }

    modifier governanceOnly() {
        require(msg.sender == governor, Errors.NOT_AUTHORIZED);
        _;
    }

    /// @notice Changes the governor
    /// can only be called by the current governor
    function changeGovernor(address newGovernor) external {
        address currentCovernor = governor;
        require(msg.sender == currentCovernor, Errors.NOT_AUTHORIZED);

        governor = newGovernor;

        emit GovernorChanged(currentCovernor, newGovernor);
    }
}
