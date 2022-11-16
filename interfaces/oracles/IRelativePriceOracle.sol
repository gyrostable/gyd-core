// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

interface IRelativePriceOracle {
    /// @notice Quotes the price of `baseToken` relative to `quoteToken`
    /// The quoted price is always scaled with 18 decimals regardless of the
    /// source used for the oracle.
    /// @param baseToken the token of which the price is to be quoted
    /// @param quoteToken the token used to denominate the price
    /// @return the number of units of quote token per base token
    function getRelativePrice(address baseToken, address quoteToken)
        external
        view
        returns (uint256);

    /// @notice Returns whether the oracle currently supports prices
    /// for `baseToken` relative to `quoteToken`
    function isPairSupported(address baseToken, address quoteToken) external view returns (bool);
}
