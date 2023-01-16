// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

/// @notice ICapAuthentication handles cap authentication for the capped protocol
interface ICapAuthentication {
    /// @return `true` if the account is authenticated
    function isAuthenticated(address account) external view returns (bool);
}
