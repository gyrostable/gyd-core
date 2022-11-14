// SPDX-License-Identifier: for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>. 
pragma solidity ^0.8.4;

import "./BalancerLPSharePricing.sol";
import "./BaseBalancerPriceOracle.sol";

import "../../../libraries/TypeConversion.sol";

import "../../../interfaces/balancer/ICPMMV3.sol";

contract BalancerCPMMV3PriceOracle is BaseBalancerPriceOracle {
    using TypeConversion for DataTypes.PricedToken[];
    using FixedPoint for uint256;

    /// @inheritdoc BaseVaultPriceOracle
    function getPoolTokenPriceUSD(
        IGyroVault vault,
        DataTypes.PricedToken[] memory underlyingPricedTokens
    ) public view override returns (uint256) {
        ICPMMV3 pool = ICPMMV3(vault.underlying());
        return
            BalancerLPSharePricing.priceBptCPMMv3(
                pool.getRoot3Alpha(),
                getInvariantDivSupply(pool),
                underlyingPricedTokens.pluckPrices()
            );
    }
}
