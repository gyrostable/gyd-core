// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./GovernableBase.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract GovernableUpgradeable is GovernableBase, Initializable {
    function initialize(address _governor) external initializer {
        governor = _governor;
        emit GovernorChanged(address(0), _governor);
    }
}
