pragma solidity ^0.8.4;

import "../libraries/DataTypes.sol";

/// @title IGydRecovery is a recovery module where providers lock GYD, which are burned in the event of a reserve shortfall. It supports a version of liquidity mining.
interface IGydRecovery {
    // TODO make this interface more complete for easier access & documentation. Stub right now.

    /// @notice Checks whether the reserve experiences a shortfall and the safety module should run and then runs it if so. This is called internally but can also be called by anyone.
    /// @return didRun Whether the safety module ran.
    function checkAndRun() external returns (bool didRun);

    /// @notice Variant of checkAndRun() where the reserve state is passed in; only callable by Motherboard.
    function checkAndRun(DataTypes.ReserveState memory reserveState) external returns (bool didRun);
}
