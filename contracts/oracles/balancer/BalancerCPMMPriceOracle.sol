// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./BalancerLPSharePricing.sol";
import "../BaseVaultPriceOracle.sol";

import "../../../libraries/TypeConversion.sol";

import "../../../interfaces/balancer/IWeightedPool.sol";

contract BalancerCPMMPriceOracle is BaseVaultPriceOracle {
    using TypeConversion for DataTypes.PricedToken[];
    using FixedPoint for uint256;

    /// @inheritdoc BaseVaultPriceOracle
    function getPoolTokenPriceUSD(
        IGyroVault vault,
        DataTypes.PricedToken[] memory underlyingPricedTokens
    ) public view override returns (uint256) {
        IWeightedPool pool = IWeightedPool(vault.underlying());
        uint256 invariant = pool.getInvariant();
        uint256 totalSupply = pool.totalSupply();
        uint256 invariantDivSupply = invariant.divDown(totalSupply);
        uint256[] memory weights = pool.getNormalizedWeights();
        return
            BalancerLPSharePricing.priceBptCPMM(
                weights,
                invariantDivSupply,
                underlyingPricedTokens.pluckPrices()
            );
    }
}
