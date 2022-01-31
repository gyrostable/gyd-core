// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IRelativePriceOracle {
    /// @notice Quotes the price of `baseAsset` relative to `quoteAsset`
    /// The quoted price is always scaled with 18 decimals regardless of the
    /// source used for the oracle.
    /// @param baseAsset the asset of which the price is to be quoted
    /// @param quoteAsset the asset used to denominate the price
    /// @return the number of units of quote asset per base asset
    function getRelativePrice(address baseAsset, address quoteAsset)
        external
        view
        returns (uint256);

    /// @notice Returns whether the oracle currently supports prices
    /// for `baseAsset` relative to `quoteAsset`
    function isPairSupported(address baseAsset, address quoteAsset) external view returns (bool);
}
