// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "../auth/Governable.sol";
import "../../interfaces/oracles/IRateManager.sol";

contract RateManager is IRateManager, Governable {
    mapping(address => IRateProvider) internal _providers;

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
            IRateProvider provider = _providers[token];
            if (address(provider) == address(0)) {
                underlyingTokens[i] = token;
                rates[i] = 1e18;
            } else {
                underlyingTokens[i] = provider.getUnderlying();
                rates[i] = provider.getRate();
            }
        }
    }

    function getProvider(address token) external view override returns (IRateProvider) {
        return _providers[token];
    }

    function setRateProvider(address token, address provider) external governanceOnly {
        _providers[token] = IRateProvider(provider);
        emit RateProviderChanged(token, provider);
    }
}
