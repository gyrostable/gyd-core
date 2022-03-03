// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/math/Math.sol";

import "../../interfaces/oracles/IUSDPriceOracle.sol";
import "../../interfaces/oracles/IRelativePriceOracle.sol";
import "../../interfaces/oracles/IUSDBatchPriceOracle.sol";

import "../auth/Governable.sol";

import "../../libraries/Errors.sol";
import "../../libraries/FixedPoint.sol";

contract CheckedPriceOracle is IUSDPriceOracle, IUSDBatchPriceOracle, Governable {
    using FixedPoint for uint256;

    uint256 public constant INITIAL_RELATIVE_EPSILON = 0.02e18;
    uint256 public constant MAX_RELATIVE_EPSILON = 0.1e18;

    address public constant USDC_ADDRESS = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant WETH_ADDRESS = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    IUSDPriceOracle public usdOracle;
    IRelativePriceOracle public relativeOracle;

    uint256 public relativeEpsilon;

    constructor(address _usdOracle, address _relativeOracle) {
        usdOracle = IUSDPriceOracle(_usdOracle);
        relativeOracle = IRelativePriceOracle(_relativeOracle);
        relativeEpsilon = INITIAL_RELATIVE_EPSILON;
    }

    /// @inheritdoc IUSDBatchPriceOracle
    function getPricesUSD(address[] memory tokenAddresses)
        external
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

        for (uint256 i = 0; i < length; i++) {
            prices[i] = usdOracle.getPriceUSD(tokenAddresses[i]);
        }

        bool[] memory checked = new bool[](length);

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
                _ensurePriceConsistency(prices[i], prices[j], relativePrice);

                checked[j] = true;
                couldCheck = true;
                break;
            }

            require(couldCheck, Errors.ASSET_NOT_SUPPORTED);

            checked[i] = true;
        }

        // keep the TWAPs that are used for ETH grounding in memory so we don't have to call again (ETH/USDC, ETH/USDT, ...), settable by gov which ones
        // do the ETH grounding consistency check with these TWAPs
        // also need to get the Coinbase signed price and OKEx signed price (or check if already on-chain recently enough), these are inputs to signedPrices
        // ETH price is coming from Chainlink, want this already in memory as well

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

        _ensurePriceConsistency(priceBaseUSD, priceComparisonTokenUSD, baseToComparisonPrice);

        return priceBaseUSD;
    }

    function setRelativeMaxEpsilon(uint256 _relativeEpsilon) external governanceOnly {
        require(_relativeEpsilon > 0, Errors.INVALID_ARGUMENT);
        require(_relativeEpsilon < MAX_RELATIVE_EPSILON, Errors.INVALID_ARGUMENT);

        relativeEpsilon = _relativeEpsilon;
    }

    function ensurePriceGrounded(
        uint256[] signedPrices,
        uint256[] twaps,
        uint256 price
    ) {}

    function _ensurePriceConsistency(
        uint256 aUSDPrice,
        uint256 bUSDPrice,
        uint256 abPrice
    ) internal view {
        uint256 abPriceFromUSD = aUSDPrice.divDown(bUSDPrice);
        uint256 priceDifference = abPrice.absSub(abPriceFromUSD);
        uint256 relativePriceDifference = priceDifference.divDown(abPrice);

        require(relativePriceDifference <= relativeEpsilon, Errors.STALE_PRICE);
    }

    function medianizeTwaps(uint256[] memory twapPrices) internal pure returns (uint256) {
        // min if there are two, or the 2nd min if more than two
        uint256 min = twapPrices[0];
        uint256 secondMin = 2**256 - 1;
        for (uint256 i = 0; i < twapPrices.length; i++) {
            if (twapPrices[i] < min) {
                secondMin = min;
                min = twapPrices[i];
            } else if (twapPrices[i] < secondMin) {
                secondMin = twapPrices[i];
            }
        }
        if (twapPrices.length == 2) {
            return min;
        } else {
            return secondMin;
        }
    }

    function swap(
        int256[] memory array,
        uint256 i,
        uint256 j
    ) internal pure {
        (array[i], array[j]) = (array[j], array[i]);
    }

    function sort(
        int256[] memory array,
        uint256 begin,
        uint256 end
    ) internal pure {
        if (begin < end) {
            uint256 j = begin;
            int256 pivot = array[j];
            for (uint256 i = begin + 1; i < end; ++i) {
                if (array[i] < pivot) {
                    swap(array, i, ++j);
                }
            }
            swap(array, begin, j);
            sort(array, begin, j);
            sort(array, j + 1, end);
        }
    }

    function median(int256[] memory array, uint256 length) internal pure returns (int256) {
        sort(array, 0, length);
        return
            length % 2 == 0
                ? Math.average(array[length / 2 - 1], array[length / 2])
                : array[length / 2];
    }

    // inputs: chainlink ETH/USD price, Coinbase ETH/USD price, OKEx ETH/USD price,  array of ETH/stablecoin TWAPS
    // compute min(ETH/stablecoin TWAPs):
    // min if there are only two, or the 2nd min if more than two
    // compute median (coinbase, OKex, min-TWAP)
    // check that chainlink is within epsilon of median
    function calculateWETHPriceAnchor(uint256[] memory signedPrices, uint256[] memory twapPrices)
        internal
        pure
        returns (uint256)
    {
        uint256 medianizedTwap = medianizeTwaps(twapPrices);
        int256[] memory prices = new int256[](signedPrices.length + 1);
        // fill in prices array with signedPrices and medianizedTwap, and safe casting to int
        uint256 priceAnchor = median(prices);
        return priceAnchor;
    }

    // function sort(uint256[] memory data) public returns (uint256[] memory) {
    //     quickSort(data, int256(0), int256(data.length - 1));
    //     return data;
    // }

    // function quickSort(
    //     uint256[] memory arr,
    //     int256 left,
    //     int256 right
    // ) internal {
    //     int256 i = left;
    //     int256 j = right;
    //     if (i == j) return;
    //     uint256 pivot = arr[uint256(left + (right - left) / 2)];
    //     while (i <= j) {
    //         while (arr[uint256(i)] < pivot) i++;
    //         while (pivot < arr[uint256(j)]) j--;
    //         if (i <= j) {
    //             (arr[uint256(i)], arr[uint256(j)]) = (arr[uint256(j)], arr[uint256(i)]);
    //             i++;
    //             j--;
    //         }
    //     }
    //     if (left < j) quickSort(arr, left, j);
    //     if (i < right) quickSort(arr, i, right);
    // }
}
