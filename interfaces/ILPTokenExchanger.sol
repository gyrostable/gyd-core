// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../libraries/DataTypes.sol";

/// @notice ILPTokenExchanger transforms underlying tokens to/from lp tokens supported by Gyro vaults
/// It can also be used to give estimates about these conversions
interface ILPTokenExchanger {
    /// @notice Returns a list of tokens supported by this exchanger to deposit
    /// to the underlying pool
    /// @dev This will typically be the tokens in the pool (e.g. ETH and DAI for an ETH/DAI pool)
    /// but we could also support swapping tokens before depositing them
    function getSupportedTokens() external view returns (address[] memory);

    /// @notice Deposits `underlyingTokenTuple` to the liquidity pool
    /// and sends back the received LP tokens as `lpTokenAmount`
    /// @param underlyingTokenTuple the underlying token and amount to deposit
    /// @return lpTokenAmount the amount of LP token deposited and sent back
    function swapIn(DataTypes.TokenTuple memory underlyingTokenTuple)
        external
        returns (uint256 lpTokenAmount);

    /// @notice Burns `lpTokenAmount` in the liquidity pool
    /// and sends back an underlyingTokenTuple
    /// @param lpTokenAmount the amount of LP token to burn
    /// @return underlyingTokenTuple the token tuple returned by the burn
    function swapOut(uint256 lpTokenAmount)
        external
        returns (DataTypes.TokenTuple memory underlyingTokenTuple);
}
