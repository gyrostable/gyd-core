// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

/// @title IReserve is the master contract
/// of the Gyro protocol
interface IReserve {
    /// @notice Deposits vault tokens in the reserve
    /// @param vault address of the vault tokens
    /// @param amount amount of the vault tokens to deposit
    function depositVaultTokens(address vault, uint256 amount) external;

    /// @notice Withdraws vault tokens from the reserve
    /// @param vault address of the vault tokens
    /// @param amount amount of the vault tokens to deposit
    function withdrawVaultTokens(address vault, uint256 amount) external;
}
