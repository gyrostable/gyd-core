// SPDX-License-Identifier: for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>. 


pragma solidity ^0.8.4;

interface IAuthorizer {
    /**
     * @dev Returns true if `account` can perform the action described by `actionId` in the contract `where`.
     */
    function canPerform(
        bytes32 actionId,
        address account,
        address where
    ) external view returns (bool);
}
