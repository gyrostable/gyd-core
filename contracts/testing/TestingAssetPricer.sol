// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../../interfaces/oracles/IUSDPriceOracle.sol";
import "../../libraries/AssetPricer.sol";

contract TestingAssetPricer {
    using AssetPricer for IUSDPriceOracle;

    IUSDPriceOracle internal priceOracle;

    constructor(IUSDPriceOracle _priceOracle) {
        priceOracle = _priceOracle;
    }

    function getUSDValue(DataTypes.MonetaryAmount memory monetaryAmount)
        external
        view
        returns (uint256)
    {
        return priceOracle.getUSDValue(monetaryAmount);
    }

    function getBasketUSDValue(DataTypes.MonetaryAmount[] memory monetaryAmounts)
        external
        view
        returns (uint256)
    {
        return priceOracle.getBasketUSDValue(monetaryAmounts);
    }
}
