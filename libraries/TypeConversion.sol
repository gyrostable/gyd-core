// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./DataTypes.sol";

library TypeConversion {
    function pluckPrices(DataTypes.PricedToken[] memory pricedTokens)
        public
        pure
        returns (uint256[] memory)
    {
        uint256[] memory prices = new uint256[](pricedTokens.length);
        for (uint256 i = 0; i < pricedTokens.length; i++) {
            prices[i] = pricedTokens[i].price;
        }
        return prices;
    }
}
