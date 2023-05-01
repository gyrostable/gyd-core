// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "./IMinimalPoolView.sol";
import "./IECLP.sol";

interface IECLPV2 is IECLP {
    function getTokenRates() external view returns (uint256, uint256);
}
