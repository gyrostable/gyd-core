// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "../libraries/DataTypes.sol";

interface IExternalActionExecutor {
    function executeAction(DataTypes.ExternalAction memory action) external;

    function executeActions(DataTypes.ExternalAction[] memory actions) external;
}
