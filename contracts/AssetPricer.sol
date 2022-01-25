// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../interfaces/IPriceOracle.sol";
import "../interfaces/IAssetPricer.sol";

import "../libraries/FixedPoint.sol";

contract AssetPricer is IAssetPricer {
    using FixedPoint for uint256;

    IPriceOracle public priceOracle;

    constructor(address _priceOracle) {
        priceOracle = IPriceOracle(_priceOracle);
    }

    /// @inheritdoc IAssetPricer
    function getUSDValue(DataTypes.MonetaryAmount memory monetaryAmount)
        public
        view
        override
        returns (uint256)
    {
        uint256 price = priceOracle.getPriceUSD(monetaryAmount.tokenAddress);
        return price.mulDown(monetaryAmount.amount);
    }

    /// @inheritdoc IAssetPricer
    function getBasketUSDValue(DataTypes.MonetaryAmount[] memory monetaryAmounts)
        external
        view
        override
        returns (uint256)
    {
        uint256 length = monetaryAmounts.length;
        uint256 total = 0;
        for (uint256 i = 0; i < length; i++) {
            total += getUSDValue(monetaryAmounts[i]);
        }
        return total;
    }
}
