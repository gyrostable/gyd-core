// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Address.sol";
import "./GovernableUpgradeable.sol";

contract GovernanceProxy is GovernableUpgradeable {
    using Address for address;

    function executeCall(address target, bytes calldata payload) external governanceOnly {
        target.functionCall(payload);
    }
}
