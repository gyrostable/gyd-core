// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../interfaces/oracles/IUSDPriceOracle.sol";
import "../interfaces/IAssetPricer.sol";
import "../interfaces/IGyroConfig.sol";

import "../libraries/FixedPoint.sol";
import "../libraries/ConfigHelpers.sol";
import "../libraries/DecimalScale.sol";

contract AssetPricer is IAssetPricer {
    using FixedPoint for uint256;
    using DecimalScale for uint256;
    using ConfigHelpers for IGyroConfig;

    IGyroConfig public immutable gyroConfig;

    constructor(address _gyroConfig) {
        gyroConfig = IGyroConfig(_gyroConfig);
    }

    /// @inheritdoc IAssetPricer
    function getUSDValue(DataTypes.MonetaryAmount memory monetaryAmount)
        external
        view
        override
        returns (uint256)
    {
        return _getUSDValue(monetaryAmount, gyroConfig.getRootPriceOracle());
    }

    /// @inheritdoc IAssetPricer
    function getBasketUSDValue(DataTypes.MonetaryAmount[] memory monetaryAmounts)
        external
        view
        override
        returns (uint256)
    {
        IUSDPriceOracle priceOracle = gyroConfig.getRootPriceOracle();
        uint256 length = monetaryAmounts.length;
        uint256 total = 0;
        for (uint256 i = 0; i < length; i++) {
            total += _getUSDValue(monetaryAmounts[i], priceOracle);
        }
        return total;
    }

    function _getUSDValue(
        DataTypes.MonetaryAmount memory monetaryAmount,
        IUSDPriceOracle priceOracle
    ) internal view returns (uint256) {
        uint256 price = priceOracle.getPriceUSD(monetaryAmount.tokenAddress);
        uint8 decimals = IERC20Metadata(monetaryAmount.tokenAddress).decimals();
        uint256 scaledAmount = monetaryAmount.amount.scaleFrom(decimals);
        return price.mulDown(scaledAmount);
    }
}
