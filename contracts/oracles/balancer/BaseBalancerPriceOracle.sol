// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./BalancerLPSharePricing.sol";
import "../BaseVaultPriceOracle.sol";

import "../../../libraries/TypeConversion.sol";

import "../../../interfaces/balancer/IMinimalPoolView.sol";

abstract contract BaseBalancerPriceOracle is BaseVaultPriceOracle {
    using TypeConversion for DataTypes.PricedToken[];
    using FixedPoint for uint256;

    function getInvariantDivSupply(IMinimalPoolView pool) internal view returns (uint256) {
        uint256 invariant = pool.getInvariant();
        uint256 totalSupply = pool.totalSupply();
        return invariant.divDown(totalSupply);
    }
}
