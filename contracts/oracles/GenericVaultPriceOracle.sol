// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./BaseVaultPriceOracle.sol";

contract GenericVaultPriceOracle is BaseVaultPriceOracle {
    /// @inheritdoc BaseVaultPriceOracle
    function getPoolTokenPriceUSD(
        IGyroVault, /* vault */
        DataTypes.PricedToken[] memory underlyingPricedTokens
    ) public pure override returns (uint256) {
        return underlyingPricedTokens[0].price;
    }
}
