// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "./BalancerLPSharePricing.sol";
import "./BaseBalancerPriceOracle.sol";

import "../../../libraries/TypeConversion.sol";

import "../../../interfaces/balancer/IECLPV2.sol";

contract BalancerECLPV2PriceOracle is BaseBalancerPriceOracle {
    using TypeConversion for DataTypes.PricedToken[];
    using TypeConversion for IECLP.DerivedParams;
    using FixedPoint for uint256;

    /// @inheritdoc BaseVaultPriceOracle
    function getPoolTokenPriceUSD(
        IGyroVault vault,
        DataTypes.PricedToken[] memory underlyingPricedTokens
    ) public view override returns (uint256) {
        IECLPV2 pool = IECLPV2(vault.underlying());
        (IECLP.Params memory params, IECLP.DerivedParams memory derivedParams) = pool
            .getECLPParams();

        (uint256 rate0, uint256 rate1) = pool.getTokenRates();
        uint256[] memory underlyingPrices = underlyingPricedTokens.pluckPrices();
        underlyingPrices[0] = underlyingPrices[0].divDown(rate0);
        underlyingPrices[1] = underlyingPrices[1].divDown(rate1);

        return
            BalancerLPSharePricing.priceBptECLP(
                params,
                derivedParams.downscaleDerivedParams(),
                getInvariantDivSupply(pool),
                underlyingPrices
            );
    }
}
