// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../auth/Governable.sol";

import "../../interfaces/oracles/IUSDPriceOracle.sol";
import "../../interfaces/vendor/ChainlinkAggregator.sol";

import "../../libraries/Errors.sol";
import "../../libraries/DecimalScale.sol";

abstract contract BaseChainlinkPriceOracle is IUSDPriceOracle, Governable {
    using DecimalScale for uint256;

    uint256 public constant MAX_LAG = 86400;

    mapping(address => address) public feeds;

    function _getLatestRoundData(address feed)
        internal
        view
        returns (
            uint80 roundId,
            uint256 price,
            uint256 updatedAt
        )
    {
        int256 answer;
        (roundId, answer, , updatedAt, ) = AggregatorV2V3Interface(feed).latestRoundData();
        require(block.timestamp <= updatedAt + MAX_LAG, Errors.STALE_PRICE);
        require(answer >= 0, Errors.NEGATIVE_PRICE);
        price = uint256(answer);
    }
}