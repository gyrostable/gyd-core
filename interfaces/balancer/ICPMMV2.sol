// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface ICPMMV2 {
    function getSqrtParameters() external view returns (uint256, uint256);

    function getInvariant() external view returns (uint256);

    function totalSupply() external view returns (uint256);
}
