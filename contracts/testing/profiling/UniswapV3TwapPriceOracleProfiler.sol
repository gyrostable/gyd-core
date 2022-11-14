// SPDX-License-Identifier: for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>. 
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
