// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/gyd-core>.
pragma solidity ^0.8.4;

import "./IGyroPool.sol";

interface I2CLP is IGyroPool {
    function getSqrtParameters() external view returns (uint256, uint256);
}
