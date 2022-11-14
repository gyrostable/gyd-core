// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "./BaseChainLinkOracle.sol";

import "../../libraries/Errors.sol";
import "../../libraries/DecimalScale.sol";

contract ChainlinkPriceOracle is BaseChainlinkPriceOracle {
    using DecimalScale for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    event FeedUpdated(address indexed asset, address indexed previousFeed, address indexed newFeed);

    /// @inheritdoc IUSDPriceOracle
    function getPriceUSD(address asset) external view override returns (uint256) {
        address feed = feeds[asset];
        require(feed != address(0), Errors.ASSET_NOT_SUPPORTED);
        (, uint256 price, ) = _getLatestRoundData(feed);
        return price.scaleFrom(AggregatorV2V3Interface(feed).decimals());
    }

    /// @notice Allows to set Chainlink feeds
    /// This can only be called by governance
    function setFeed(address asset, address feed) external virtual governanceOnly {
        address previousFeed = feeds[asset];
        require(feed != previousFeed, Errors.INVALID_ARGUMENT);
        _supportedAssets.add(asset);
        feeds[asset] = feed;
        emit FeedUpdated(asset, previousFeed, feed);
    }
}
