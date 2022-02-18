// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @notice A vault is one of the component of the reserve and has a one-to-one
/// mapping to an underlying pool (e.g. Balancer pool, Curve pool, Uniswap pool...)
/// It is itself an ERC-20 token that is used to track the ownership of the LP tokens
/// deposited in the vault
/// A vault can be associated with a strategy to generate yield on the deposited funds
interface IGyroVault is IERC20Metadata {
    /// @return The token associated with this vault
    function underlying() external view returns (address);

    /// @return The total amount of underlying tokens in the vault
    function totalUnderlying() external view returns (uint256);

    /// @return The exchange rate between an underlying tokens and the token of this vault
    function exchangeRate() external view returns (uint256);

    /// @notice Deposits `underlyingAmount` of LP token supported
    /// and sends back the received vault tokens
    /// @param underlyingAmount the amount of underlying to deposit
    /// @return vaultTokenAmount the amount of vault token sent back
    function deposit(uint256 underlyingAmount, uint256 minVaultTokensOut)
        external
        returns (uint256 vaultTokenAmount);

    /// @notice Simlar to `deposit(uint256 underlyingAmount)` but credits the tokens
    /// to `beneficiary` instead of `msg.sender`
    function depositFor(
        address beneficiary,
        uint256 underlyingAmount,
        uint256 minVaultTokensOut
    ) external returns (uint256 vaultTokenAmount);

    /// @notice Dry-run version of deposit
    function dryDeposit(uint256 underlyingAmount, uint256 minVaultTokensOut)
        external
        view
        returns (uint256 vaultTokenAmount, string memory error);

    /// @notice Withdraws `vaultTokenAmount` of LP token supported
    /// and burns the vault tokens
    /// @param vaultTokenAmount the amount of vault token to withdraw
    /// @return underlyingAmount the amount of LP token sent back
    function withdraw(uint256 vaultTokenAmount, uint256 minUnderlyingOut)
        external
        returns (uint256 underlyingAmount);

    /// @notice Dry-run version of `withdraw`
    function dryWithdraw(uint256 vaultTokenAmount, uint256 minUnderlyingOut)
        external
        view
        returns (uint256 underlyingAmount, string memory error);

    /// @return The address of the current strategy used by the vault
    function strategy() external view returns (address);

    /// @notice Sets the address of the strategy to use for this vault
    /// This will be used through governance
    /// @param strategyAddress the address of the strategy contract that should follow the `IStrategy` interface
    function setStrategy(address strategyAddress) external;
}
