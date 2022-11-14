// SPDX-License-Identifier: for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>. 
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IFeeBank.sol";
import "./auth/Governable.sol";

contract FeeBank is IFeeBank, Governable {
    using SafeERC20 for IERC20;

    constructor() Governable() {}

    /// @inheritdoc IFeeBank
    function depositFees(address underlying, uint256 amount) external override {
        IERC20(underlying).safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @inheritdoc IFeeBank
    function withdrawFees(
        address underlying,
        address beneficiary,
        uint256 amount
    ) external override governanceOnly {
        IERC20(underlying).safeTransfer(beneficiary, amount);
    }
}
