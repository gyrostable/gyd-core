// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "./BalancerLPSharePricing.sol";
import "./BaseBalancerPriceOracle.sol";

import "../../../libraries/TypeConversion.sol";

import "../../../interfaces/balancer/ICEMM.sol";

contract BalancerCEMMPriceOracle is BaseBalancerPriceOracle {
    using TypeConversion for DataTypes.PricedToken[];
    using FixedPoint for uint256;

    /// @inheritdoc BaseVaultPriceOracle
    function getPoolTokenPriceUSD(
        IGyroVault vault,
        DataTypes.PricedToken[] memory underlyingPricedTokens
    ) public view override returns (uint256) {
        ICEMM pool = ICEMM(vault.underlying());
        (ICEMM.Params memory params, ICEMM.DerivedParams memory derivedParams) = pool
            .getParameters();
        return
            BalancerLPSharePricing.priceBptCEMM(
                params,
                derivedParams,
                getInvariantDivSupply(pool),
                underlyingPricedTokens.pluckPrices()
            );
    }
}
