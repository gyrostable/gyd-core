// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../../libraries/Errors.sol";
import "../../interfaces/IGovernable.sol";

contract Governable is IGovernable {
    address public override governor;

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
    function changeGovernor(address newGovernor) external override {
        address currentCovernor = governor;
        require(msg.sender == currentCovernor, Errors.NOT_AUTHORIZED);

        governor = newGovernor;

        emit GovernorChanged(currentCovernor, newGovernor);
    }
}
