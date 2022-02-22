// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../interfaces/IGyroVault.sol";
import "../../libraries/FixedPoint.sol";
import "../../libraries/Errors.sol";

contract BaseVault is IGyroVault, ERC20 {
    using FixedPoint for uint256;
    using SafeERC20 for IERC20;

    /// @inheritdoc IGyroVault
    address public immutable override underlying;

    /// @inheritdoc IGyroVault
    address public override strategy;

    constructor(
        address _underlying,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        underlying = _underlying;
    }

    /// @inheritdoc IGyroVault
    function vaultType() external pure virtual override returns (VaultType) {
        return VaultType.GENERIC;
    }

    /// @inheritdoc IGyroVault
    function getTokens() external view virtual override returns (IERC20[] memory) {
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(underlying);
        return tokens;
    }

    /// @inheritdoc IERC20Metadata
    function decimals() public view virtual override(ERC20, IERC20Metadata) returns (uint8) {
        return IERC20Metadata(underlying).decimals();
    }

    /// @inheritdoc IGyroVault
    function totalUnderlying() public view override returns (uint256) {
        // TODO: account for amount invested in strategy
        return IERC20(underlying).balanceOf(address(this));
    }

    /// @inheritdoc IGyroVault
    function exchangeRate() public view override returns (uint256) {
        uint256 totalUnderlying_ = totalUnderlying();
        uint256 totalSupply = totalSupply();
        if (totalSupply == 0 || totalUnderlying_ == 0) {
            return FixedPoint.ONE;
        }

        return totalUnderlying_.divDown(totalSupply);
    }

    /// @inheritdoc IGyroVault
    function deposit(uint256 underlyingAmount, uint256 minVaultTokensOut)
        external
        override
        returns (uint256 vaultTokensMinted)
    {
        return depositFor(msg.sender, underlyingAmount, minVaultTokensOut);
    }

    /// @inheritdoc IGyroVault
    function depositFor(
        address beneficiary,
        uint256 underlyingAmount,
        uint256 minVaultTokensOut
    ) public override returns (uint256 vaultTokensMinted) {
        uint256 rate = exchangeRate();

        IERC20(underlying).safeTransferFrom(msg.sender, address(this), underlyingAmount);

        vaultTokensMinted = underlyingAmount.divDown(rate);
        require(vaultTokensMinted >= minVaultTokensOut, Errors.TOO_MUCH_SLIPPAGE);

        _mint(beneficiary, vaultTokensMinted);

        return vaultTokensMinted;
    }

    /// @inheritdoc IGyroVault
    function dryDeposit(uint256 underlyingAmount, uint256 minVaultTokensOut)
        external
        view
        override
        returns (uint256 vaultTokensMinted, string memory err)
    {
        uint256 rate = exchangeRate();
        vaultTokensMinted = underlyingAmount.divDown(rate);
        if (vaultTokensMinted < minVaultTokensOut) {
            err = Errors.TOO_MUCH_SLIPPAGE;
        }
    }

    /// @inheritdoc IGyroVault
    function withdraw(uint256 vaultTokenAmount, uint256 minUnderlyingOut)
        external
        override
        returns (uint256 underlyingAmountWithdrawn)
    {
        require(vaultTokenAmount > 0, Errors.INVALID_ARGUMENT);

        uint256 vaultTokenBalance = balanceOf(msg.sender);
        require(vaultTokenBalance >= vaultTokenAmount, Errors.INSUFFICIENT_BALANCE);

        uint256 rate = exchangeRate();
        underlyingAmountWithdrawn = vaultTokenAmount.mulDown(rate);
        require(underlyingAmountWithdrawn >= minUnderlyingOut, Errors.TOO_MUCH_SLIPPAGE);

        _burn(msg.sender, vaultTokenAmount);
        IERC20(underlying).safeTransfer(msg.sender, underlyingAmountWithdrawn);
    }

    /// @inheritdoc IGyroVault
    function dryWithdraw(uint256 vaultTokenAmount, uint256 minUnderlyingOut)
        external
        view
        override
        returns (uint256 underlyingAmountWithdrawn, string memory err)
    {
        uint256 rate = exchangeRate();
        underlyingAmountWithdrawn = vaultTokenAmount.mulDown(rate);
        if (underlyingAmountWithdrawn < minUnderlyingOut) {
            err = Errors.TOO_MUCH_SLIPPAGE;
        }
    }

    /// @inheritdoc IGyroVault
    function setStrategy(address strategyAddress) external override {
        strategy = strategyAddress;
    }
}