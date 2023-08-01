// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "./BaseChainLinkOracle.sol";

import "../../libraries/FixedPoint.sol";

contract CrashProtectedChainlinkPriceOracle is BaseChainlinkPriceOracle {
    using DecimalScale for uint256;
    using FixedPoint for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    event FeedUpdated(
        address indexed asset,
        address indexed previousFeed,
        address indexed newFeed,
        FeedMeta meta
    );

    struct FeedMeta {
        uint64 minDiffTime;
        uint64 maxDeviation;
    }

    mapping(address => FeedMeta) public feedMetas;

    constructor(address _governor) BaseChainlinkPriceOracle(_governor) {}

    /// @inheritdoc IUSDPriceOracle
    function getPriceUSD(address asset) external view override returns (uint256) {
        address feed = feeds[asset];
        require(feed != address(0), Errors.ASSET_NOT_SUPPORTED);
        (uint80 roundId, uint256 price, uint256 lastUpdate) = _getLatestRoundData(feed);

        FeedMeta memory meta = feedMetas[feed];

        // we look for the first update that happened at least `minDiffTime` ago
        int256 previousAnswer;
        uint256 previousUpdate;
        do {
            roundId -= 1;
            (, previousAnswer, , previousUpdate, ) = AggregatorV3Interface(feed).getRoundData(
                roundId
            );
        } while (lastUpdate - previousUpdate < meta.minDiffTime);

        require(previousAnswer >= 0, Errors.NEGATIVE_PRICE);
        uint256 previousPrice = uint256(previousAnswer);
        uint256 deviation = previousPrice.absSub(price).divDown(price);
        require(deviation < meta.maxDeviation, Errors.TOO_MUCH_VOLATILITY);

        return price.scaleFrom(AggregatorV3Interface(feed).decimals());
    }

    /// @notice Allows to set Chainlink feeds with the metadata
    function setFeed(
        address asset,
        address feed,
        FeedMeta memory feedMeta
    ) public governanceOnly {
        address previousFeed = feeds[asset];
        require(feed != previousFeed, Errors.INVALID_ARGUMENT);
        require(feedMeta.minDiffTime > 0, Errors.INVALID_ARGUMENT);
        feeds[asset] = feed;
        feedMetas[feed] = feedMeta;
        _supportedAssets.add(asset);
        emit FeedUpdated(asset, previousFeed, feed, feedMeta);
    }
}
