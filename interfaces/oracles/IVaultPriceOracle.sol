// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../../libraries/DataTypes.sol";

import "../IGyroVault.sol";

interface IVaultPriceOracle {
    /// @notice Quotes the USD price of `vault` tokens
    /// The quoted price is always scaled with 18 decimals regardless of the
    /// source used for the oracle.
    /// @param vault the vault of which the price is to be quoted
    /// @return the USD price of the vault token
    function getPriceUSD(IGyroVault vault, DataTypes.PricedToken[] memory underlyingPricedTokens)
        external
        view
        returns (uint256);
}
