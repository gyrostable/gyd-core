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

    function getInvariantDivSupply(IMinimalPoolView pool) internal view returns (uint256) {
        // NOTE: this is a workaround to avoid issues with the Balancer pool contracts
        // this is only required for our proto deployment and will be reverted to
        // uint256 invariant = pool.getInvariant();
        // for the mainnet launch
        uint256 invariant = pool.getLastInvariant();
        uint256 totalSupply = pool.totalSupply();
        return invariant.divDown(totalSupply);
    }
}
