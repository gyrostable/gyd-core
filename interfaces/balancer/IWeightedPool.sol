// SPDX-License-Identifier: for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>. 
pragma solidity ^0.8.4;

import "./IMinimalPoolView.sol";

interface IWeightedPool is IMinimalPoolView {
    function getNormalizedWeights() external view returns (uint256[] memory);
}
