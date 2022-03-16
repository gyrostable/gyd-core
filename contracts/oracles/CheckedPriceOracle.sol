// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../../interfaces/oracles/IUSDPriceOracle.sol";
import "../../interfaces/oracles/IRelativePriceOracle.sol";
import "../../interfaces/oracles/IUSDBatchPriceOracle.sol";
import "../../libraries/EnumerableExtensions.sol";

import "../auth/Governable.sol";

import "../../libraries/Errors.sol";
import "../../libraries/FixedPoint.sol";

contract CheckedPriceOracle is IUSDPriceOracle, IUSDBatchPriceOracle, Governable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableExtensions for EnumerableSet.AddressSet;

    using FixedPoint for uint256;
    using SafeCast for uint256;
    using SafeCast for int256;

    uint256 public constant MAX_ABSOLUTE_WETH_DEVIATION = 0.02e18;
    uint256 public constant INITIAL_RELATIVE_EPSILON = 0.02e18;
    uint256 public constant MAX_RELATIVE_EPSILON = 0.1e18;

    address public constant USDC_ADDRESS = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant WETH_ADDRESS = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    IUSDPriceOracle public usdOracle;
    IRelativePriceOracle public relativeOracle;

    uint256 public relativeEpsilon;

    address[] public signedPriceAddresses;

    EnumerableSet.AddressSet internal quoteAssetsForPriceLevelTWAPS;

    event QuoteAssetForPriceLevelChanged(string, address _addedAddress);

    /// _usdOracle is for Chainlink
    constructor(address _usdOracle, address _relativeOracle) {
        usdOracle = IUSDPriceOracle(_usdOracle);
        relativeOracle = IRelativePriceOracle(_relativeOracle);
        relativeEpsilon = INITIAL_RELATIVE_EPSILON;
    }

    /// This should be setting the contract addresses for the trusted Signed Price Oracles
    function setSignedPriceAddresses(address[] memory newSignedPriceAddresses)
        external
        governanceOnly
    {
        signedPriceAddresses = newSignedPriceAddresses;
    }

    function setQuoteAssetsForPriceLevelCheckTWAPs(address[] memory _newQuoteAssets)
        external
        governanceOnly
    {
        /// This list is going to be used for the twaps to be input into the price level checks.
        /// These are the addresses of the assets to be paired with ETH e.g. USDC or USDT
        for (uint256 i = 0; i < _newQuoteAssets.length; i++) {
            bool success = quoteAssetsForPriceLevelTWAPS.add(_newQuoteAssets[i]);
            if (success) {
                emit QuoteAssetForPriceLevelChanged("Quote asset added", _newQuoteAssets[i]);
            }
        }
    }

    function removeQuoteAssetsForPriceLevelCheckTWAPs(address[] memory _quoteAssetsToRemove)
        external
        governanceOnly
    {
        /// This list is going to be used for the twaps to be input into the price level checks.
        /// These are the addresses of the assets to be paired with ETH e.g. USDC or USDT
        for (uint256 i = 0; i < _quoteAssetsToRemove.length; i++) {
            bool success = quoteAssetsForPriceLevelTWAPS.remove(_quoteAssetsToRemove[i]);
            if (success) {
                emit QuoteAssetForPriceLevelChanged("Quote asset removed", _quoteAssetsToRemove[i]);
            }
        }
    }

    function batchRelativePriceCheck(
        address[] memory tokenAddresses,
        uint256 length,
        uint256[] memory prices
    ) internal view returns (uint256[] memory) {
        bool[] memory checked = new bool[](length);

        uint256[] memory priceLevelTwaps = new uint256[](quoteAssetsForPriceLevelTWAPS.length());

        for (uint256 i = 0; i < tokenAddresses.length - 1; i++) {
            if (checked[i]) {
                continue;
            }

            bool couldCheck = false;
            for (uint256 j = i + 1; j < tokenAddresses.length; j++) {
                if (!relativeOracle.isPairSupported(tokenAddresses[i], tokenAddresses[j])) {
                    continue;
                }

                // This is a TWAP
                uint256 relativePrice = relativeOracle.getRelativePrice(
                    tokenAddresses[i],
                    tokenAddresses[j]
                );

                if (
                    (tokenAddresses[i] == WETH_ADDRESS) &&
                    (quoteAssetsForPriceLevelTWAPS.contains(tokenAddresses[j]))
                ) {
                    priceLevelTwaps[i] = relativePrice;
                }

                _ensureRelativePriceConsistency(prices[i], prices[j], relativePrice);

                checked[j] = true;
                couldCheck = true;
                break;
            }

            require(couldCheck, Errors.ASSET_NOT_SUPPORTED);

            checked[i] = true;
        }

        return priceLevelTwaps;
    }

    //NB this is expected to be queried for ALL asset prices in the reserve
    /// @inheritdoc IUSDBatchPriceOracle
    function getPricesUSD(address[] memory tokenAddresses)
        public
        view
        override
        returns (uint256[] memory)
    {
        uint256 length = tokenAddresses.length;
        require(length > 0, Errors.INVALID_ARGUMENT);

        uint256[] memory prices = new uint256[](length);

        if (tokenAddresses.length == 1) {
            prices[0] = getPriceUSD(tokenAddresses[0]);
            return prices;
        }

        /// Will start with this being the WETH/USD price, this can be modified later if desired.
        uint256 priceLevel;

        for (uint256 i = 0; i < length; i++) {
            prices[i] = usdOracle.getPriceUSD(tokenAddresses[i]);
            if (tokenAddresses[i] == WETH_ADDRESS) {
                priceLevel = prices[i];
            }
        }

        uint256[] memory priceLevelTwaps = batchRelativePriceCheck(tokenAddresses, length, prices);

        uint256[] memory signedPrices = new uint256[](signedPriceAddresses.length);

        for (uint256 i = 0; i < signedPriceAddresses.length; i++) {
            /// Ensure that given ETH/USD price from coinbase and the ETH/USD price from
            /// OKex are the prices that get saved in this array
            /// Q: will these prices be retrieved if just the contract address is provided?
            /// Q: is this the right way to do this gas wise?
            signedPrices[i] = usdOracle.getPriceUSD(signedPriceAddresses[i]);
        }

        _checkPriceLevel(priceLevel, signedPrices, priceLevelTwaps);

        return prices;
    }

    /// @inheritdoc IUSDPriceOracle
    function getPriceUSD(address tokenAddress) public view override returns (uint256) {
        address comparisonToken = tokenAddress == WETH_ADDRESS ? USDC_ADDRESS : WETH_ADDRESS;
        uint256 baseToComparisonPrice = relativeOracle.getRelativePrice(
            tokenAddress,
            comparisonToken
        );
        uint256 priceBaseUSD = usdOracle.getPriceUSD(tokenAddress);
        uint256 priceComparisonTokenUSD = usdOracle.getPriceUSD(comparisonToken);

        //TODO: do we need to ensure the individual feeds are ETH price grounded too? This is used in the reserve safety checker, for example.
        _ensureRelativePriceConsistency(
            priceBaseUSD,
            priceComparisonTokenUSD,
            baseToComparisonPrice
        );

        return priceBaseUSD;
    }

    function setRelativeMaxEpsilon(uint256 _relativeEpsilon) external governanceOnly {
        require(_relativeEpsilon > 0, Errors.INVALID_ARGUMENT);
        require(_relativeEpsilon < MAX_RELATIVE_EPSILON, Errors.INVALID_ARGUMENT);

        relativeEpsilon = _relativeEpsilon;
    }

    function _checkPriceLevel(
        uint256 priceLevel,
        uint256[] memory signedPrices,
        uint256[] memory priceLevelTwaps
    ) internal view {
        uint256 trueWETH = getRobustWETHPrice(signedPrices, priceLevelTwaps);
        uint256 absolutePriceDifference = priceLevel.absSub(trueWETH);
        require(
            absolutePriceDifference <= MAX_ABSOLUTE_WETH_DEVIATION,
            Errors.ROOT_PRICE_NOT_GROUNDED
        );
    }

    function _ensureRelativePriceConsistency(
        uint256 aUSDPrice,
        uint256 bUSDPrice,
        uint256 abPrice
    ) internal view {
        uint256 abPriceFromUSD = aUSDPrice.divDown(bUSDPrice);
        uint256 priceDifference = abPrice.absSub(abPriceFromUSD);
        uint256 relativePriceDifference = priceDifference.divDown(abPrice);

        require(relativePriceDifference <= relativeEpsilon, Errors.STALE_PRICE);
    }

    function _computeMinOrSecondMin(uint256[] memory twapPrices) internal pure returns (uint256) {
        // min if there are two, or the 2nd min if more than two
        uint256 min = twapPrices[0];
        uint256 secondMin = 2**256 - 1;
        for (uint256 i = 1; i < twapPrices.length; i++) {
            if (twapPrices[i] < min) {
                secondMin = min;
                min = twapPrices[i];
            } else if ((twapPrices[i] < secondMin)) {
                secondMin = twapPrices[i];
            }
        }
        if (twapPrices.length == 1) {
            return twapPrices[0];
        } else if (twapPrices.length == 2) {
            return min;
        } else {
            return secondMin;
        }
    }

    function _sort(uint256[] memory data) internal view returns (uint256[] memory) {
        _quickSort(data, int256(0), int256(data.length - 1));
        return data;
    }

    function _quickSort(
        uint256[] memory arr,
        int256 left,
        int256 right
    ) internal view {
        int256 i = left;
        int256 j = right;
        if (i == j) return;
        uint256 pivot = arr[uint256(left + (right - left) / 2)];
        while (i <= j) {
            while (arr[uint256(i)] < pivot) i++;
            while (pivot < arr[uint256(j)]) j--;
            if (i <= j) {
                (arr[uint256(i)], arr[uint256(j)]) = (arr[uint256(j)], arr[uint256(i)]);
                i++;
                j--;
            }
        }
        if (left < j) _quickSort(arr, left, j);
        if (i < right) _quickSort(arr, i, right);
    }

    function _median(uint256[] memory array) internal view returns (uint256) {
        _sort(array);
        return
            array.length % 2 == 0
                ? Math.average(array[array.length / 2 - 1], array[array.length / 2])
                : array[array.length / 2];
    }

    /// @notice this function provides an estimate of the true WETH price.
    /// 1. Find the minimum TWAP price (or second minumum if >2 TWAP prices) from a given array.
    /// 2. Add this to an array of signed prices
    /// 3. Compute the median of this array
    /// @param signedPrices an array of prices from trusted providers (e.g. Chainlink, Coinbase, OKEx ETH/USD price)
    /// @param twapPrices an array of Time Weighted Moving Average ETH/stablecoin prices
    function getRobustWETHPrice(uint256[] memory signedPrices, uint256[] memory twapPrices)
        public
        view
        returns (uint256)
    {
        uint256 medianizedTwap;
        if (twapPrices.length == 0) {
            return _median(signedPrices);
        } else {
            medianizedTwap = _computeMinOrSecondMin(twapPrices);
            uint256[] memory prices = new uint256[](signedPrices.length + 1);
            for (uint256 i = 0; i < prices.length; i++) {
                if (i == prices.length - 1) {
                    prices[i] = medianizedTwap;
                } else {
                    prices[i] = signedPrices[i];
                }
            }
            return _median(prices);
        }
    }
}
