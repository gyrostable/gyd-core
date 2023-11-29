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

    /// @notice input token may have a rate such as sDAI or aUSDC, or be a "normal" token such as DAI or USDC
    /// @return underlyingToken the "underlying" token, e.g. DAI instead of sDAI
    /// @return rate the rate of the token
    /// @dev if the token does not have a rate, its address will be returned as-is and its rate will be 1e18
    function getUnderlyingAndRate(address token)
        external
        view
        returns (address underlyingToken, uint256 rate);

    /// @return the info about the rate provider for the given token
    function getProviderInfo(address token) external view returns (RateProviderInfo memory);
}
