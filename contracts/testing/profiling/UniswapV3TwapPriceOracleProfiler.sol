// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../../oracles/UniswapV3TwapPriceOracle.sol";

contract UniswapV3TwapOracleProfiler is UniswapV3TwapOracle {
    function profileGetRelativePrice(address[] calldata baseAssets, address[] calldata quoteAssets)
        external
    {
        uint32 window = timeWindowLengthSeconds;
        for (uint256 i = 0; i < baseAssets.length; i++) {
            getRelativePrice(baseAssets[i], quoteAssets[i], window);
        }
    }
}
