// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "./IRateProvider.sol";

interface IRateManager {
    event RateProviderChanged(address indexed token, RateProviderInfo providerInfo);

    struct RateProviderInfo {
        address underlying;
        IRateProvider provider;
    }

    /// @notice input tokens may contain tokens that have a rate, such as sDAI or aUSDC
    /// @return underlyingTokens the array of "underlying" tokens, e.g. DAI instead of sDAI
    /// @return rates the array of rates for each token in the tokens array
    /// @dev if a token does not have a rate, its address will be returned in `tokens`
    /// and its rate will be 1e18
    function getTokensAndRates(address[] memory inputTokens)
        external
        view
        returns (address[] memory underlyingTokens, uint256[] memory rates);

    /// @return the info about the rate provider for the given token
    function getProviderInfo(address token) external view returns (RateProviderInfo memory);
}
