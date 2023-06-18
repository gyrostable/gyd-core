// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "./BalancerLPSharePricing.sol";
import "./BaseBalancerPriceOracle.sol";

import "../../../libraries/TypeConversion.sol";

import "../../../interfaces/balancer/IECLP.sol";

/// @notice OBSOLETE, only here for backwards compatibility. Use ECLPV2 instead!
contract BalancerECLPPriceOracle is BaseBalancerPriceOracle {
    using TypeConversion for DataTypes.PricedToken[];
    using TypeConversion for IECLP.DerivedParams;
    using FixedPoint for uint256;

    function getInvariantDivSupply(IMinimalPoolView pool) internal view returns (uint256) {
        // Temporary workaround. To be removed (so the base class's version is used) in the mainnet deployment.
        uint256 invariant = pool.getLastInvariant();
        uint256 totalSupply = pool.totalSupply();
        return invariant.divDown(totalSupply);
    }

    /// @inheritdoc BaseVaultPriceOracle
    function getPoolTokenPriceUSD(
        IGyroVault vault,
        DataTypes.PricedToken[] memory underlyingPricedTokens
    ) public view override returns (uint256) {
        IECLP pool = IECLP(vault.underlying());
        (IECLP.Params memory params, IECLP.DerivedParams memory derivedParams) = pool
            .getECLPParams();
        return
            BalancerLPSharePricing.priceBptECLP(
                params,
                derivedParams.downscaleDerivedParams(),
                getInvariantDivSupply(pool),
                underlyingPricedTokens.pluckPrices()
            );
    }
}
