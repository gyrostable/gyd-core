// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../auth/GovernableUpgradeable.sol";
import "../../interfaces/IGyroVault.sol";
import "../../libraries/FixedPoint.sol";
import "../../libraries/Errors.sol";

abstract contract BaseVault is IGyroVault, ERC20PermitUpgradeable, GovernableUpgradeable {
    using FixedPoint for uint256;
    using SafeERC20 for IERC20;

    address internal constant _DEAD = 0x000000000000000000000000000000000000dEaD;

    /// @dev the number of shares to burn on first mint
    /// we burn 10 shares for low decimals assets (e.g. USDC with 6 decimals)
    /// and 1000 shares for high decimals assets (e.g. WETH with 18 decimals)
    /// this should be a negligible amount in all cases
    uint256 internal constant _SHARES_LOW_DECIMALS = 10;
    uint256 internal constant _SHARES_HIGH_DECIMALS = 1000;
    uint8 internal constant _HIGH_DECIMALS_THRESHOLD = 8;

    uint256[50] internal __gapBaseVault;

    /// @inheritdoc IGyroVault
    address public override underlying;

    /// @inheritdoc IGyroVault
    uint256 public override deployedAt;

    /// @inheritdoc IGyroVault
    address public override strategy;

    /// @inheritdoc IERC20MetadataUpgradeable
    function decimals()
        public
        view
        virtual
        override(ERC20Upgradeable, IERC20MetadataUpgradeable)
        returns (uint8)
    {
        return IERC20Metadata(underlying).decimals();
    }

    /// @inheritdoc IGyroVault
    function totalUnderlying() public view override returns (uint256) {
        // TODO: account for amount invested in strategy
        return IERC20(underlying).balanceOf(address(this));
    }

    /// @inheritdoc IGyroVault
    function exchangeRate() public view override returns (uint256) {
        return _exchangeRate(false);
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
        uint256 rate = _exchangeRate(true);

        IERC20(underlying).safeTransferFrom(msg.sender, address(this), underlyingAmount);

        vaultTokensMinted = underlyingAmount.divDown(rate);

        if (totalSupply() == 0) {
            uint256 sharesToBurn = _sharesToBurn();
            _mint(_DEAD, sharesToBurn);
            vaultTokensMinted -= sharesToBurn;
        }

        require(vaultTokensMinted > 0, Errors.NO_SHARES_MINTED);

        require(vaultTokensMinted >= minVaultTokensOut, Errors.TOO_MUCH_SLIPPAGE);

        _mint(beneficiary, vaultTokensMinted);
    }

    /// @inheritdoc IGyroVault
    function dryDeposit(uint256 underlyingAmount, uint256 minVaultTokensOut)
        external
        view
        override
        returns (uint256 vaultTokensMinted, string memory err)
    {
        uint256 rate = _exchangeRate(true);
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
    function setStrategy(address strategyAddress) external override governanceOnly {
        strategy = strategyAddress;
    }

    function _exchangeRate(bool overAproximate) internal view returns (uint256) {
        uint256 totalUnderlying_ = totalUnderlying();
        uint256 totalSupply = totalSupply();
        if (totalSupply == 0) {
            return FixedPoint.ONE;
        }

        return
            overAproximate
                ? totalUnderlying_.divUp(totalSupply)
                : totalUnderlying_.divDown(totalSupply);
    }

    function _sharesToBurn() internal view returns (uint256) {
        return decimals() > _HIGH_DECIMALS_THRESHOLD ? _SHARES_HIGH_DECIMALS : _SHARES_LOW_DECIMALS;
    }

    function __BaseVault_initialize(
        address _underlying,
        address governor,
        string memory name,
        string memory symbol
    ) internal {
        require(address(_underlying) != address(0), Errors.INVALID_ARGUMENT);
        underlying = _underlying;
        deployedAt = block.number;
        __GovernableUpgradeable_initialize(governor);
        __ERC20_init(name, symbol);
        __ERC20Permit_init(name);
    }
}
