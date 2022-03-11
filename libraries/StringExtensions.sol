// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

library StringExtensions {
    function compareStrings(string memory a, string memory b) public pure returns (bool) {
        if (bytes(a).length != bytes(b).length) {
            return false;
        }
        return (keccak256(bytes(a)) == keccak256(bytes(b)));
    }
}
