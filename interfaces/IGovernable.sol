// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IGovernable {
    /// @notice Emmited when the governor is changed
    event GovernorChanged(address oldGovernor, address newGovernor);

    /// @notice Returns the current governor
    function governor() external view returns (address);

    /// @notice Changes the governor
    /// can only be called by the current governor
    function changeGovernor(address newGovernor) external;
}
