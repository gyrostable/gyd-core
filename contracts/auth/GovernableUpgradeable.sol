// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "./GovernableBase.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract GovernableUpgradeable is GovernableBase, Initializable {
    uint256[50] internal __gap;

    constructor() {
        _disableInitializers();
    }

    // solhint-disable-next-line func-name-mixedcase
    function __GovernableUpgradeable_initialize(address _governor) internal {
        governor = _governor;
        emit GovernorChanged(address(0), _governor);
    }

    function initialize(address _governor) external virtual initializer {
        __GovernableUpgradeable_initialize(_governor);
    }
}
