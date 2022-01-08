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

    /// @notice Deposits `underlyingMonetaryAmount` to the liquidity pool
    /// and sends back the received LP tokens as `lpTokenAmount`
    /// @param tokenToDeposit the underlying token and amount to deposit
    function deposit(DataTypes.MonetaryAmount memory tokenToDeposit)
        external
        returns (uint256 lpTokenAmount);

    /// @notice Dry version of `deposit`
    /// @param tokenToDeposit the underlying token and amount to deposit
    /// @return lpTokenAmount the received LP tokens as `lpTokenAmount`
    function dryDeposit(DataTypes.MonetaryAmount memory tokenToDeposit)
        external
        returns (uint256 lpTokenAmount, string memory err);

    /// @notice Withdraws token from the liquidity pool
    /// and sends back an underlyingMonetaryAmount
    /// @param tokenToWithdraw the underlying token and amount to withdraw
    function withdraw(DataTypes.MonetaryAmount memory tokenToWithdraw)
        external
        returns (uint256 lpTokenAmount);
}
