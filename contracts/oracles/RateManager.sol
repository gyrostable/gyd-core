// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "../auth/Governable.sol";
import "../../interfaces/oracles/IRateManager.sol";

contract RateManager is IRateManager, Governable {
    mapping(address => RateProviderInfo) internal _providers;

    constructor(address _governor) Governable(_governor) {}

    function getTokensAndRates(address[] memory inputTokens)
        external
        view
        override
        returns (address[] memory underlyingTokens, uint256[] memory rates)
    {
        underlyingTokens = new address[](inputTokens.length);
        rates = new uint256[](inputTokens.length);

        for (uint256 i; i < inputTokens.length; i++) {
            address token = inputTokens[i];
            IRateProvider provider = _providers[token].provider;
            if (address(provider) == address(0)) {
                underlyingTokens[i] = token;
                rates[i] = 1e18;
            } else {
                underlyingTokens[i] = _providers[token].underlying;
                rates[i] = provider.getRate();
            }
        }
    }

    function getProviderInfo(address token)
        external
        view
        override
        returns (RateProviderInfo memory)
    {
        return _providers[token];
    }

    function setRateProviderInfo(address token, RateProviderInfo memory providerInfo)
        external
        governanceOnly
    {
        _providers[token] = providerInfo;
        emit RateProviderChanged(token, providerInfo);
    }
}
