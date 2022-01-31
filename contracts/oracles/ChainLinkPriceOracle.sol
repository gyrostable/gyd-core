// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../auth/Governable.sol";

import "../../interfaces/oracles/IUSDPriceOracle.sol";
import "../../interfaces/vendor/ChainlinkAggregator.sol";

import "../../libraries/Errors.sol";
import "../../libraries/DecimalScale.sol";

contract ChainlinkPriceOracle is IUSDPriceOracle, Governable {
    using DecimalScale for uint256;

    event FeedUpdated(address indexed asset, address indexed previousFeed, address indexed newFeed);

    uint256 public constant MAX_LAG = 86400;

    mapping(address => address) public feeds;

    /// @inheritdoc IUSDPriceOracle
    function getPriceUSD(address asset) external view override returns (uint256) {
        address feed = feeds[asset];
        require(feed != address(0), Errors.ASSET_NOT_SUPPORTED);

        (, int256 answer, , uint256 updatedAt, ) = AggregatorV2V3Interface(feed).latestRoundData();

        require(block.timestamp <= updatedAt + MAX_LAG, Errors.STALE_PRICE);
        require(answer >= 0, Errors.NEGATIVE_PRICE);

        uint256 price = uint256(answer);
        uint8 decimals = AggregatorV2V3Interface(feed).decimals();
        return price.scaleFrom(decimals);
    }

    /// @notice Allows to set Chainlink feeds
    /// This can only be called by governance
    function setFeed(address asset, address feed) external governanceOnly {
        address previousFeed = feeds[asset];
        require(feed != previousFeed, Errors.INVALID_ARGUMENT);
        feeds[asset] = feed;
        emit FeedUpdated(asset, previousFeed, feed);
    }
}
