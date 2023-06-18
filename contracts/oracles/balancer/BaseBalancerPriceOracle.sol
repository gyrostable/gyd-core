// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "./BalancerLPSharePricing.sol";
import "../BaseVaultPriceOracle.sol";

import "../../../libraries/TypeConversion.sol";

import "../../../interfaces/balancer/IMinimalPoolView.sol";

abstract contract BaseBalancerPriceOracle is BaseVaultPriceOracle {
    using TypeConversion for DataTypes.PricedToken[];
    using FixedPoint for uint256;

    /// @dev This function is not used for Gyro CLPs, which have a separate view function to get
    ///the same thing in a more gas-efficient way.
    function getInvariantDivActualSupply(IMinimalPoolView pool)
        internal
        view
        virtual
        returns (uint256)
    {
        uint256 invariant = pool.getInvariant();
        uint256 actualSupply = pool.getActualSupply();
        return invariant.divDown(actualSupply);
    }
}
