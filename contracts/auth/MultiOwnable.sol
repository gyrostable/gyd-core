// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../../libraries/Errors.sol";

abstract contract MultiOwnable is Initializable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet internal _owners;

    modifier onlyOwner() {
        require(_owners.contains(msg.sender), Errors.NOT_AUTHORIZED);
        _;
    }

    // solhint-disable-next-line func-name-mixedcase
    function __MultiOwnable_initialize(address owner) internal {
        _owners.add(owner);
    }

    function addOwner(address owner) external onlyOwner {
        require(!_owners.contains(owner), Errors.INVALID_ARGUMENT);
        _owners.add(owner);
    }

    function removeOwner(address owner) external onlyOwner {
        require(owner != msg.sender, Errors.NOT_AUTHORIZED);
        require(_owners.contains(owner), Errors.INVALID_ARGUMENT);
        _owners.remove(owner);
    }

    function owners() external view returns (address[] memory) {
        return _owners.values();
    }
}