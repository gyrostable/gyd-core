// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "./BalancerLPSharePricing.sol";
import "./BaseBalancerPriceOracle.sol";

import "../../../libraries/TypeConversion.sol";

import "../../../interfaces/balancer/I2CLP.sol";

contract Balancer2CLPPriceOracle is BaseBalancerPriceOracle {
    using TypeConversion for DataTypes.PricedToken[];
    using FixedPoint for uint256;

    /// @inheritdoc BaseVaultPriceOracle
    function getPoolTokenPriceUSD(
        IGyroVault vault,
        DataTypes.PricedToken[] memory underlyingPricedTokens
    ) public view override returns (uint256) {
        I2CLP pool = I2CLP(vault.underlying());
        (uint256 sqrtAlpha, uint256 sqrtBeta) = pool.getSqrtParameters();
        return
            BalancerLPSharePricing.priceBpt2CLP(
                sqrtAlpha,
                sqrtBeta,
                pool.getInvariantDivActualSupply(),
                underlyingPricedTokens.pluckPrices()
            );
    }
}
