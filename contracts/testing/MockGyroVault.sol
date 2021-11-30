// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../../interfaces/IVault.sol";
import "OpenZeppelin/openzeppelin-contracts@4.3.2/contracts/token/ERC20/ERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.3.2/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.3.2/contracts/token/ERC20/IERC20.sol";

contract MockGyroVault is IVault, ERC20 {
    using SafeERC20 for IERC20;

    address _strategy;
    address _lpToken;

    constructor(address lpToken_) ERC20("Vault", "VLT") {
        _lpToken = lpToken_;
    }

    function lpToken() external view override returns (address) {
        return _lpToken;
    }

    function deposit(uint256 lpTokenAmount) external override returns (uint256 vaultTokenAmount) {
        return depositFor(msg.sender, lpTokenAmount);
    }

    function depositFor(address beneficiary, uint256 lpTokenAmount)
        public
        override
        returns (uint256 vaultTokenAmount)
    {
        IERC20(_lpToken).safeTransferFrom(msg.sender, beneficiary, lpTokenAmount);
        _mint(beneficiary, lpTokenAmount);
        return lpTokenAmount;
    }

    function dryDeposit(uint256 lpTokenAmount)
        external
        pure
        override
        returns (uint256 vaultTokenAmount, string memory error)
    {
        return (lpTokenAmount, "");
    }

    function dryDepositFor(address, uint256 lpTokenAmount)
        external
        pure
        override
        returns (uint256 vaultTokenAmount, string memory error)
    {
        return (lpTokenAmount, "");
    }

    function withdraw(uint256 vaultTokenAmount) external override returns (uint256 lpTokenAmount) {
        _burn(msg.sender, vaultTokenAmount);
        IERC20(_lpToken).transfer(msg.sender, vaultTokenAmount);
        return vaultTokenAmount;
    }

    function dryWithdraw(uint256 vaultTokenAmount)
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
