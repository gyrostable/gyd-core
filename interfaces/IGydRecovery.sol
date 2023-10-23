// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "../libraries/DataTypes.sol";

/// @title IGydRecovery is a recovery module where providers lock GYD, which are burned in the event of a reserve shortfall. It supports a version of liquidity mining.
interface IGydRecovery {
    // TODO make this interface more complete for easier access & documentation. Stub right now.

    /// @notice Checks whether the reserve experiences a shortfall and the safety module should run and then runs it if so. This is called internally but can also be called by anyone.
    /// @return didRun Whether the safety module ran.
    function checkAndRun() external returns (bool didRun);

    /// @notice Whether the reserve should run under current conditions, i.e., whether it would run if `checkAndRun()` was called.
    function shouldRun() external view returns (bool);

    /// @notice Variant of checkAndRun() where the reserve state is passed in; only callable by Motherboard.
    function checkAndRun(DataTypes.ReserveState memory reserveState) external returns (bool didRun);
}
