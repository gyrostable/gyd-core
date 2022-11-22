// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./MultiOwnable.sol";
import "../../interfaces/ICapAuthentication.sol";

contract CapAuthentication is MultiOwnable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet internal _authenticatedAccounts;

    constructor() {
        _authenticatedAccounts.add(msg.sender);
    }

    function authenticate(address account) external onlyOwner {
        _authenticatedAccounts.add(account);
    }

    function deauthenticate(address account) external onlyOwner {
        _authenticatedAccounts.remove(account);
    }

    function isAuthenticated(address account) external view returns (bool) {
        return _authenticatedAccounts.contains(account);
    }

    function listAuthenticatedAccounts() external view returns (address[] memory) {
        return _authenticatedAccounts.values();
    }
}
