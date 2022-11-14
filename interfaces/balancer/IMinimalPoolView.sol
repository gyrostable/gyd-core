// SPDX-License-Identifier: for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>. 
pragma solidity ^0.8.4;

interface IMinimalPoolView {
    function getInvariant() external view returns (uint256);

    function totalSupply() external view returns (uint256);
}
