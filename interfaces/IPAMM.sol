// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./../libraries/DataTypes.sol";

/// @title IPAMM is the pricing contract for the Primary Market
interface IPAMM {
    /// @notice Quotes the amount of GYD for `vaultTokenAmounts`
    /// @param vaultTokenAmounts a basket of vault token and associated amounts to be priced
    /// @param mintFee the fee to be charged for minting
    /// @return gydAmount the price of the input basket in GYD
    function calculateGYDToMint(DataTypes.TokenAmount[] memory vaultTokenAmounts, uint256 mintFee)
        external
        returns (uint256 gydAmount);

    /// @notice This function has the same input and outputs than `calculateGYDToMint`
    /// but actually executes the minting, recording the required information
    /// in the PAMM
    function calculateAndRecordGYDToMint(
        DataTypes.TokenAmount[] memory vaultTokenAmounts,
        uint256 mintFee
    ) external returns (uint256 gydAmount);

    /// @notice Quotes the amount of GYD for `vaultTokenAmounts`
    /// @param vaultTokenAmounts an basket of vault token and associated amounts  to be priced
    /// @param redeemFee the fee to be charged for redeeming
    /// @return gydAmount the price of the input basket in GYD
    function calculateGYDToBurn(DataTypes.TokenAmount[] memory vaultTokenAmounts, uint256 redeemFee)
        external
        returns (uint256 gydAmount);
}
