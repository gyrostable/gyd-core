// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

/// @notice IFeeBank is where the fees will be stored
interface IFeeBank {
    /// @notice Returns the address of the controller of the FeeBank
    /// this will typically be the motherboard or another contract in charge of
    /// managing the Gyroscope fees
    function controllerAddress() external view returns (address);

    /// @notice Deposits `amount` of `underlying` in the fee bank
    /// @dev the fee bank should be approved to spend at least `amount` of `underlying`
    function depositFees(address underlying, uint256 amount) external;

    /// @notice Withdraws `amount` of `underlying` from the fee bank
    function withdrawFees(address underlying, uint256 amount) external;
}
