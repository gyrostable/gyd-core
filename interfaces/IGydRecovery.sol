pragma solidity ^0.8.4;

import "../libraries/DataTypes.sol";

/// @title IGydRecovery is a recovery module where providers lock GYD, which are burned in the event of a reserve shortfall. It supports a version of liquidity mining.
interface IGydRecovery {
    // TODO maybe make this interface more complete for easier access & documentation. Stub right now.

    /// @notice Checks whether the reserve experiences a shortfall and the safety module should run and then runs it if so.
    ///
    /// @param reserveState Reserve state fetched via `ReserveManager.getReserveState()`.
    /// @return didRun Whether the safety module ran.
    function checkAndRun(DataTypes.ReserveState memory reserveState) external returns (bool didRun);

    /// @notice Like `checkAndRun(ReserveState)` but fetches the reserve state itself.
    function checkAndRun() external returns (bool);
}
