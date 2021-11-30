// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "OpenZeppelin/openzeppelin-contracts@4.3.2/contracts/token/ERC20/IERC20.sol";

/// @notice A vault is one of the component of the reserve and has a one-to-one
/// mapping to an underlying pool (e.g. Balancer pool, Curve pool, Uniswap pool...)
/// It is itself an ERC-20 token that is used to track the ownership of the LP tokens
/// deposited in the vault
/// A vault can be associated with a strategy to generate yield on the deposited funds
interface IVault is IERC20 {
    /// @return The LP token associated with this vault
    function lpToken() external view returns (address);

    /// @notice Deposits `lpTokenAmount` of LP token supported
    /// and sends back the received vault tokens
    /// @param lpTokenAmount the amount of LP token to deposit
    /// @return vaultTokenAmount the amount of vault token sent back
    function deposit(uint256 lpTokenAmount) external returns (uint256 vaultTokenAmount);

    /// @notice Simlar to `deposit(uint256 lpTokenAmount)` but credits the tokens
    /// to `beneficiary` instead of `msg.sender`
    function depositFor(address beneficiary, uint256 lpTokenAmount)
        external
        returns (uint256 vaultTokenAmount);

    /// @notice Dry-run version of deposit
    function dryDeposit(uint256 lpTokenAmount)
        external
        view
        returns (uint256 vaultTokenAmount, string memory error);

    /// @notice Dry-run version of depositFor
    function dryDepositFor(address beneficiary, uint256 lpTokenAmount)
        external
        view
        returns (uint256 vaultTokenAmount, string memory error);

    /// @notice Withdraws `vaultTokenAmount` of LP token supported
    /// and burns the vault tokens
    /// @param vaultTokenAmount the amount of vault token to withdraw
    /// @return lpTokenAmount the amount of LP token sent back
    function withdraw(uint256 vaultTokenAmount) external returns (uint256 lpTokenAmount);

    /// @notice Dry-run version of `withdraw`
    function dryWithdraw(uint256 vaultTokenAmount)
        external
        view
        returns (uint256 lpTokenAmount, string memory error);

    /// @return The address of the current strategy used by the vault
    function strategy() external view returns (address);

    /// @notice Sets the address of the strategy to use for this vault
    /// This will be used through governance
    /// @param strategyAddress the address of the strategy contract that should follow the `IStrategy` interface
    function setStrategy(address strategyAddress) external;
}
