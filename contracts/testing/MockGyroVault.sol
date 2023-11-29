// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../interfaces/IGyroVault.sol";

import "../../libraries/FixedPoint.sol";

contract MockGyroVault is IGyroVault, ERC20PermitUpgradeable {
    using SafeERC20 for IERC20;

    address internal _strategy;
    address internal _underlying;
    IERC20[] internal _tokens;

    uint256 public deployedAt;

    function initialize(address underlying_) external initializer {
        _underlying = underlying_;
        __ERC20_init("Vault", "VLT");
        __ERC20Permit_init("Vault");
        deployedAt = block.number;
    }

    function vaultType() external pure override returns (Vaults.Type) {
        return Vaults.Type.GENERIC;
    }

    function getTokens() external view override returns (IERC20[] memory) {
        return _tokens;
    }

    function setTokens(IERC20[] calldata tokens) external {
        _tokens = tokens;
    }

    function underlying() external view override returns (address) {
        return _underlying;
    }

    function totalUnderlying() external view override returns (uint256) {
        return IERC20(_underlying).balanceOf(address(this));
    }

    function deposit(uint256 lpTokenAmount, uint256 minOut)
        external
        override
        returns (uint256 vaultTokenAmount)
    {
        return depositFor(msg.sender, lpTokenAmount, minOut);
    }

    function exchangeRate() public pure override returns (uint256) {
        return FixedPoint.ONE;
    }

    function getRate() public pure override returns (uint256) {
        return FixedPoint.ONE;
    }

    function depositFor(
        address beneficiary,
        uint256 lpTokenAmount,
        uint256
    ) public override returns (uint256 vaultTokenAmount) {
        IERC20(_underlying).safeTransferFrom(msg.sender, beneficiary, lpTokenAmount);
        _mint(beneficiary, lpTokenAmount);
        return lpTokenAmount;
    }

    function dryDeposit(uint256 lpTokenAmount, uint256)
        external
        pure
        override
        returns (uint256 vaultTokenAmount, string memory error)
    {
        return (lpTokenAmount, "");
    }

    function withdraw(uint256 vaultTokenAmount, uint256)
        external
        override
        returns (uint256 lpTokenAmount)
    {
        _burn(msg.sender, vaultTokenAmount);
        IERC20(_underlying).transfer(msg.sender, vaultTokenAmount);
        return vaultTokenAmount;
    }

    function dryWithdraw(uint256 vaultTokenAmount, uint256)
        external
        pure
        override
        returns (uint256 lpTokenAmount, string memory error)
    {}

    function strategy() external view override returns (address) {
        return _strategy;
    }

    function setStrategy(address strategyAddress) external override {
        _strategy = strategyAddress;
    }
}
