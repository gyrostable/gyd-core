// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

/// @notice ILPTokenExchanger transforms underlying tokens to/from lp tokens supported by Gyro vaults
/// It can also be used to give estimates about these conversions
interface ILPTokenExchanger {
    /// @notice Deposits `underlyingAmount` of `underlyingToken`
    /// and sends back the received LP tokens
    /// @param underlyingToken the underlying token to deposit
    /// @param underlyingAmount the amount of `underlyingToken` to deposit
    /// @param lpToken the LP token to exchange the `underlyingToken` into
    /// @return lpTokenAmount the amount of LP token deposited and sent back
    function deposit(
        address underlyingToken,
        uint256 underlyingAmount,
        address lpToken
    ) external returns (uint256 lpTokenAmount);
}
