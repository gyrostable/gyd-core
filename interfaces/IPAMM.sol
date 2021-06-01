// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/// @title IPAMM is the pricing contract for the Primary Market
interface IPAMM {
    /// @notice Quotes the amount of GYD for `inputAmounts` of `inputTokens`
    /// @param inputTokens an basket of token addresses to be priced
    /// @param inputAmounts the amounts of each component in the basket
    /// @param state the arbitrary state of the system (e.g. inflow and outflow history)
    /// @param nav the net asset value of the reserve
    /// @param mintFee the fee to be charged for minting
    /// @return gydAmount the price of the input basket in GYD
    function calculateGYDToMint(
        address[] memory inputTokens,
        uint256[] memory inputAmounts,
        uint256 state,
        uint256 nav,
        uint256 mintFee
    ) external returns (uint256 gydAmount);

    /// @notice Quotes the amount of GYD for `inputAmounts` of `inputTokens`
    /// @param inputTokens an basket of token addresses to be priced
    /// @param inputAmounts the amounts of each component in the basket
    /// @param state the arbitrary state of the system (e.g. inflow and outflow history)
    /// @param nav the net asset value of the reserve
    /// @param redeemFee the fee to be charged for redeeming
    /// @return gydAmount the price of the input basket in GYD
    function calculateGYDToBurn(
        address[] memory inputTokens,
        uint256[] memory inputAmounts,
        uint256 state,
        uint256 nav,
        uint256 redeemFee
    ) external returns (uint256 gydAmount);
}
