// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../libraries/DataTypes.sol";

/// @notice ILPTokenExchanger transforms underlying tokens to/from lp tokens supported by Gyro vaults
/// It can also be used to give estimates about these conversions
interface ILPTokenExchanger {
    /// @notice Deposits `underlyingAmountAmount` to the liquidity pool
    /// and sends back the received LP tokens
    /// @param underlyingTokenAmount the underlying token and amount to deposit
    /// @param lpToken the LP token to exchange the `underlyingToken` into
    /// @return lpTokenAmount the amount of LP token deposited and sent back
    function deposit(DataTypes.TokenAmount memory underlyingTokenAmount, address lpToken)
        external
        returns (uint256 lpTokenAmount);
}
