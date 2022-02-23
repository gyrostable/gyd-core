// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../interfaces/oracles/IUSDPriceOracle.sol";

import "../libraries/DataTypes.sol";
import "../libraries/FixedPoint.sol";
import "../libraries/DecimalScale.sol";

library AssetPricer {
    using FixedPoint for uint256;
    using DecimalScale for uint256;

    /// @notice Quotes the USD value of `monetaryAmount`
    /// @param monetaryAmount a token and associated amount to be priced
    /// @return the USD value of the token
    function getUSDValue(
        IUSDPriceOracle priceOracle,
        DataTypes.MonetaryAmount memory monetaryAmount
    ) internal view returns (uint256) {
        uint256 price = priceOracle.getPriceUSD(monetaryAmount.tokenAddress);
        uint8 decimals = IERC20Metadata(monetaryAmount.tokenAddress).decimals();
        uint256 scaledAmount = monetaryAmount.amount.scaleFrom(decimals);
        return price.mulDown(scaledAmount);
    }

    /// @notice Quotes the USD value of `monetaryAmounts`
    /// @param monetaryAmounts a basket of tokens and associated amounts to be priced
    /// @return the USD value of the tokens
    function getBasketUSDValue(
        IUSDPriceOracle priceOracle,
        DataTypes.MonetaryAmount[] memory monetaryAmounts
    ) internal view returns (uint256) {
        uint256 length = monetaryAmounts.length;
        uint256 total = 0;
        for (uint256 i = 0; i < length; i++) {
            total += getUSDValue(priceOracle, monetaryAmounts[i]);
        }
        return total;
    }
}
