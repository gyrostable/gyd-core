// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IMinimalPoolView {
    function getInvariant() external view returns (uint256);

    function totalSupply() external view returns (uint256);
}
