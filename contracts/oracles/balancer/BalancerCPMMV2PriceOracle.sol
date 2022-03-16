// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./BalancerLPSharePricing.sol";
import "../BaseVaultPriceOracle.sol";

import "../../../libraries/TypeConversion.sol";

import "../../../interfaces/balancer/ICPMMV2.sol";

contract BalancerCPMMV2PriceOracle is BaseVaultPriceOracle {
    using TypeConversion for DataTypes.PricedToken[];
    using FixedPoint for uint256;

    /// @inheritdoc BaseVaultPriceOracle
    function getPoolTokenPriceUSD(
        IGyroVault vault,
        DataTypes.PricedToken[] memory underlyingPricedTokens
    ) public view override returns (uint256) {
        ICPMMV2 pool = ICPMMV2(vault.underlying());
        uint256 invariant = pool.getInvariant();
        uint256 totalSupply = pool.totalSupply();
        uint256 invariantDivSupply = invariant.divDown(totalSupply);
        (uint256 sqrtAlpha, uint256 sqrtBeta) = pool.getSqrtParameters();
        return
            BalancerLPSharePricing.priceBptCPMMv2(
                sqrtAlpha,
                sqrtBeta,
                invariantDivSupply,
                underlyingPricedTokens.pluckPrices()
            );
    }
}
