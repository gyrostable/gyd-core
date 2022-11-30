// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract GovernanceProxy is OwnableUpgradeable {
    using Address for address;

    function initialize(address _owner) external initializer {
        __Ownable_init();
        transferOwnership(_owner);
    }

    function executeCall(address target, bytes calldata payload) external onlyOwner {
        target.functionCall(payload);
    }
}
