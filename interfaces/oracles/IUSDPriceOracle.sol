// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IUSDPriceOracle {
    /// @notice Quotes the USD price of `baseAsset`
    /// The quoted price is always scaled with 18 decimals regardless of the
    /// source used for the oracle.
    /// @param baseAsset the asset of which the price is to be quoted
    /// @return the USD price of the asset
    function getPriceUSD(address baseAsset) external view returns (uint256);
}
