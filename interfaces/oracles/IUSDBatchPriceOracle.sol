// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

interface IUSDBatchPriceOracle {
    /// @notice Quotes the USD price of `baseAssets`
    /// The quoted prices is always scaled with 18 decimals regardless of the
    /// source used for the oracle.
    /// @param baseAssets the assets of which the price is to be quoted
    /// @return the USD prices of the asset
    function getPricesUSD(address[] memory baseAssets) external view returns (uint256[] memory);
}
