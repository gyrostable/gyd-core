// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../oracles/CheckedPriceOracle.sol";

contract TestingCheckedPriceOracle is CheckedPriceOracle {
    constructor(IUSDPriceOracle _priceOracle, IRelativePriceOracle _relativeOracle)
        CheckedPriceOracle(address(_priceOracle), address(_relativeOracle))
    {}

    function ensureRootPriceGrounded(
        uint256 mainRootPrice,
        uint256[] memory signedPrices,
        uint256[] memory twaps
    ) external view {
        return _ensureRootPriceGrounded(mainRootPrice, signedPrices, twaps);
    }

    function medianizeTwaps(uint256[] memory twapPrices) external pure returns (uint256) {
        return _medianizeTwaps(twapPrices);
    }

    function median(uint256[] memory array) external view returns (uint256) {
        return _median(array);
    }
}
