// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "./DataTypes.sol";

library TypeConversion {
    function pluckPrices(DataTypes.PricedToken[] memory pricedTokens)
        internal
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
