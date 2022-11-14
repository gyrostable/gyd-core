// SPDX-License-Identifier: for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>. 
pragma solidity ^0.8.4;

import "./BalancerLPSharePricing.sol";
import "./BaseBalancerPriceOracle.sol";

import "../../../libraries/TypeConversion.sol";

import "../../../interfaces/balancer/ICPMMV2.sol";

contract BalancerCPMMV2PriceOracle is BaseBalancerPriceOracle {
    using TypeConversion for DataTypes.PricedToken[];
    using FixedPoint for uint256;

    /// @inheritdoc BaseVaultPriceOracle
    function getPoolTokenPriceUSD(
        IGyroVault vault,
        DataTypes.PricedToken[] memory underlyingPricedTokens
    ) public view override returns (uint256) {
        ICPMMV2 pool = ICPMMV2(vault.underlying());
        (uint256 sqrtAlpha, uint256 sqrtBeta) = pool.getSqrtParameters();
        return
            BalancerLPSharePricing.priceBptCPMMv2(
                sqrtAlpha,
                sqrtBeta,
                getInvariantDivSupply(pool),
                underlyingPricedTokens.pluckPrices()
            );
    }
}
