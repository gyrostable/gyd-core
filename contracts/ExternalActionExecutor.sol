// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Address.sol";

import "../interfaces/IExternalActionExecutor.sol";

import "../libraries/Errors.sol";

contract ExternalActionExecutor is IExternalActionExecutor {
    using Address for address;

    function executeActions(DataTypes.ExternalAction[] memory actions) external override {
        for (uint256 i = 0; i < actions.length; i++) {
            executeAction(actions[i]);
        }
    }

    function executeAction(DataTypes.ExternalAction memory action) public override {
        action.target.functionCall(action.data, Errors.EXTERNAL_ACTION_FAILED);
    }
}
