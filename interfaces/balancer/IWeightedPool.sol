// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./IMinimalPoolView.sol";

interface IWeightedPool is IMinimalPoolView {
    function getNormalizedWeights() external view returns (uint256[] memory);
}
