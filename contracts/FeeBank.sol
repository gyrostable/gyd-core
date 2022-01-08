// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IFeeBank.sol";
import "./auth/Governable.sol";

contract FeeBank is IFeeBank, Governable {
    using SafeERC20 for IERC20;

    constructor() Governable() {}

    /// @inheritdoc IFeeBank
    function depositFees(address underlying, uint256 amount) external override {
        IERC20(underlying).transferFrom(msg.sender, address(this), amount);
    }

    /// @inheritdoc IFeeBank
    function withdrawFees(
        address underlying,
        address beneficiary,
        uint256 amount
    ) external override governanceOnly {
        IERC20(underlying).transfer(beneficiary, amount);
    }
}
