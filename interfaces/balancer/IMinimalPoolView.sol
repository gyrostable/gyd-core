// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

interface IMinimalPoolView {
    function getInvariant() external view returns (uint256);

    function getLastInvariant() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    // NOTE: We do NOT currently support old v1 pools that don't have this function but instead pay
    // protocol fees in pool tokens.
    function getActualSupply() external view returns (uint256);
}
