// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../../interfaces/IPriceOracle.sol";

contract MockPriceOracle is IPriceOracle {
    mapping(address => uint256) internal prices;

    /// @inheritdoc IPriceOracle
    /// @dev this is a dummy function that tries to read from the state
    /// and otherwise simply returns 1
    function getPriceUSD(address baseAsset) external view returns (uint256) {
        uint256 cachedPrice = prices[baseAsset];
        return cachedPrice == 0 ? 1e18 : cachedPrice;
    }

    function setPrice(address baseAsset, uint256 price) external {
        prices[baseAsset] = price;
    }
}
