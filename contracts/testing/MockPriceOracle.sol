// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../../interfaces/oracles/IUSDPriceOracle.sol";
import "../../interfaces/oracles/IRelativePriceOracle.sol";
import "../../libraries/Errors.sol";
import "../../libraries/FixedPoint.sol";

contract MockPriceOracle is IUSDPriceOracle, IRelativePriceOracle {
    using FixedPoint for uint256;

    mapping(address => uint256) internal usdPrices;
    mapping(address => mapping(address => uint256)) internal relativePrices;

    /// @inheritdoc IUSDPriceOracle
    function getPriceUSD(address baseAsset) external view returns (uint256) {
        uint256 cachedPrice = usdPrices[baseAsset];
        require(cachedPrice != 0, Errors.ASSET_NOT_SUPPORTED);
        return cachedPrice;
    }

    /// @inheritdoc IRelativePriceOracle
    /// @dev this is a dummy function that tries to read from the state
    function getRelativePrice(address baseAsset, address quoteAsset)
        external
        view
        returns (uint256)
    {
        uint256 relativePrice = relativePrices[baseAsset][quoteAsset];
        if (relativePrice != 0) {
            return relativePrice;
        }
        relativePrice = relativePrices[quoteAsset][baseAsset];
        if (relativePrice != 0) {
            return FixedPoint.divUp(FixedPoint.ONE, relativePrice);
        }
        revert(Errors.ASSET_NOT_SUPPORTED);
    }

    /// @inheritdoc IRelativePriceOracle
    function isPairSupported(address baseAsset, address quoteAsset) public view returns (bool) {
        return
            relativePrices[baseAsset][quoteAsset] != 0 ||
            relativePrices[quoteAsset][baseAsset] != 0;
    }

    function setUSDPrice(address baseAsset, uint256 price) external {
        usdPrices[baseAsset] = price;
    }

    function setRelativePrice(
        address baseAsset,
        address quoteAsset,
        uint256 price
    ) external {
        relativePrices[baseAsset][quoteAsset] = price;
    }
}
