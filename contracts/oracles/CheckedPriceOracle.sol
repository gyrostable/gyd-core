// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../../interfaces/oracles/IUSDPriceOracle.sol";
import "../../interfaces/oracles/IRelativePriceOracle.sol";
import "../../interfaces/oracles/IUSDBatchPriceOracle.sol";

import "../auth/Governable.sol";

import "../../libraries/Errors.sol";
import "../../libraries/FixedPoint.sol";

contract CheckedPriceOracle is IUSDPriceOracle, IUSDBatchPriceOracle, Governable {
    using FixedPoint for uint256;

    uint256 public constant INITIAL_RELATIVE_MAX_EPSILON = 0.02e18;
    uint256 public constant MAX_RELATIVE_MAX_EPSILON = 0.1e18;

    address public constant USDC_ADDRESS = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant WETH_ADDRESS = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    IUSDPriceOracle public usdOracle;
    IRelativePriceOracle public relativeOracle;

    uint256 public relativeMaxEpsilon;

    constructor(address _usdOracle, address _relativeOracle) {
        usdOracle = IUSDPriceOracle(_usdOracle);
        relativeOracle = IRelativePriceOracle(_relativeOracle);
        relativeMaxEpsilon = INITIAL_RELATIVE_MAX_EPSILON;
    }

    /// @inheritdoc IUSDBatchPriceOracle
    function getPricesUSD(address[] memory assets)
        external
        view
        override
        returns (uint256[] memory)
    {
        uint256 length = assets.length;
        require(length > 0, Errors.INVALID_ARGUMENT);

        uint256[] memory prices = new uint256[](length);

        if (assets.length == 1) {
            prices[0] = getPriceUSD(assets[0]);
            return prices;
        }

        for (uint256 i = 0; i < length; i++) {
            prices[i] = usdOracle.getPriceUSD(assets[i]);
        }

        bool[] memory checked = new bool[](length);

        assets = _normalizeBaseAssets(assets);

        for (uint256 i = 0; i < assets.length - 1; i++) {
            if (checked[i]) {
                continue;
            }

            bool couldCheck = false;
            for (uint256 j = i + 1; j < assets.length; j++) {
                if (!relativeOracle.isPairSupported(assets[i], assets[j])) {
                    continue;
                }

                uint256 relativePrice = relativeOracle.getRelativePrice(assets[i], assets[j]);
                _ensurePriceConsistency(prices[i], prices[j], relativePrice);

                checked[j] = true;
                couldCheck = true;
                break;
            }

            require(couldCheck, Errors.ASSET_NOT_SUPPORTED);

            checked[i] = true;
        }

        return prices;
    }

    /// @inheritdoc IUSDPriceOracle
    function getPriceUSD(address asset) public view override returns (uint256) {
        address comparisonAsset = asset == WETH_ADDRESS ? USDC_ADDRESS : WETH_ADDRESS;
        uint256 baseToComparisonPrice = relativeOracle.getRelativePrice(asset, comparisonAsset);
        uint256 priceBaseUSD = usdOracle.getPriceUSD(asset);
        uint256 priceComparisonAssetUSD = usdOracle.getPriceUSD(comparisonAsset);

        _ensurePriceConsistency(priceBaseUSD, priceComparisonAssetUSD, baseToComparisonPrice);

        return priceBaseUSD;
    }

    function setRelativeMaxEpsilon(uint256 _relativeMaxEpsilon) external governanceOnly {
        require(_relativeMaxEpsilon > 0, Errors.INVALID_ARGUMENT);
        require(_relativeMaxEpsilon < MAX_RELATIVE_MAX_EPSILON, Errors.INVALID_ARGUMENT);

        relativeMaxEpsilon = _relativeMaxEpsilon;
    }

    function _ensurePriceConsistency(
        uint256 aUSDPrice,
        uint256 bUSDPrice,
        uint256 abPrice
    ) internal view {
        uint256 abPriceFromUSD = aUSDPrice.divDown(bUSDPrice);
        uint256 priceDifference = abPrice.absSub(abPriceFromUSD);
        uint256 relativePriceDifference = priceDifference.divDown(abPrice);

        require(relativePriceDifference <= relativeMaxEpsilon, Errors.STALE_PRICE);
    }

    function _normalizeBaseAssets(address[] memory baseAssets)
        internal
        pure
        returns (address[] memory)
    {
        if (baseAssets.length > 1) {
            return baseAssets;
        }
        address[] memory normalizedBaseAssets = new address[](2);
        normalizedBaseAssets[0] = baseAssets[0];
        normalizedBaseAssets[1] = baseAssets[0] == WETH_ADDRESS ? USDC_ADDRESS : WETH_ADDRESS;
        return normalizedBaseAssets;
    }
}
