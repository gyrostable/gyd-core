// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../../libraries/Errors.sol";
import "../../interfaces/IGovernable.sol";

contract Governable is IGovernable {
    address public override governor;
    address public override pendingGovernor;

    constructor() {
        governor = msg.sender;
        emit GovernorChanged(address(0), msg.sender);
    }

    modifier governanceOnly() {
        require(msg.sender == governor, Errors.NOT_AUTHORIZED);
        _;
    }

    /// @inheritdoc IGovernable
    function changeGovernor(address newGovernor) external override governanceOnly {
        pendingGovernor = newGovernor;
        emit GovernorChangeRequested(newGovernor);
    }

    /// @inheritdoc IGovernable
    function acceptGovernance() external override {
        require(msg.sender == pendingGovernor, Errors.NOT_AUTHORIZED);
        address currentGovernor = governor;
        governor = pendingGovernor;
        pendingGovernor = address(0);
        emit GovernorChanged(currentGovernor, msg.sender);
    }
}
