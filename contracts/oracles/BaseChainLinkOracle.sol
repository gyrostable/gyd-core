// SPDX-License-Identifier: for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>. 
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../auth/Governable.sol";

import "../../interfaces/oracles/IUSDPriceOracle.sol";
import "../../interfaces/vendor/ChainlinkAggregator.sol";

import "../../libraries/Errors.sol";
import "../../libraries/DecimalScale.sol";

abstract contract BaseChainlinkPriceOracle is IUSDPriceOracle, Governable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using DecimalScale for uint256;

    uint256 public constant MAX_LAG = 86400;

    EnumerableSet.AddressSet internal _supportedAssets;
    mapping(address => address) public feeds;

    function listSupportedAssets() external view returns (address[] memory) {
        return _supportedAssets.values();
    }

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
