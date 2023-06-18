// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "./IGyroPool.sol";
import "./IECLP.sol";

interface IECLPV2 is IECLP, IGyroPool {
    function getTokenRates() external view returns (uint256, uint256);
}
