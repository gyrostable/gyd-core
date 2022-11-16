// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "./GovernableBase.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract GovernableUpgradeable is GovernableBase, Initializable {
    function initialize(address _governor) external initializer {
        governor = _governor;
        emit GovernorChanged(address(0), _governor);
    }
}
