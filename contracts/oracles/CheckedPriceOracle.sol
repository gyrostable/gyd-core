// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
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

    using FixedPoint for uint256;
    using SafeCast for uint256;
    using SafeCast for int256;

    uint256 public constant MAX_ABSOLUTE_WETH_DEVIATION = 50e18;
    uint256 public constant INITIAL_RELATIVE_EPSILON = 0.02e18;
    uint256 public constant MAX_RELATIVE_EPSILON = 0.1e18;

    address public immutable wethAddress;

    IUSDPriceOracle public usdOracle;
    IRelativePriceOracle public relativeOracle;

    uint256 public relativeEpsilon;

    EnumerableSet.AddressSet internal trustedSignerPriceOracles;

    /// This list is going to be used for the twaps to be input into the price level checks.
    /// These are the addresses of the assets to be paired with ETH e.g. USDC or USDT
    EnumerableSet.AddressSet internal quoteAssetsForPriceLevelTWAPS;

    /// @dev This list is used to check if the relative price of the tokens are consistent
    EnumerableSet.AddressSet internal assetsForRelativePriceCheck;

    event USDOracleUpdated(address indexed oracle);
    event RelativeOracleUpdated(address indexed oracle);

    event PriceLevelTWAPQuoteAssetAdded(address _addressToAdd);
    event PriceLevelTWAPQuoteAssetRemoved(address _addressToRemove);

    event AssetForRelativePriceCheckAdded(address _addressToAdd);
    event AssetForRelativePriceCheckRemoved(address _addressToRemove);

    event TrustedSignerOracleAdded(address _addressToAdd);
    event TrustedSignerOracleRemoved(address _addressToRemove);

    /// _usdOracle is for Chainlink
    constructor(
        address _usdOracle,
        address _relativeOracle,
        address _wethAddress
    ) {
        require(_usdOracle != address(0), Errors.INVALID_ARGUMENT);
        require(_relativeOracle != address(0), Errors.INVALID_ARGUMENT);
        usdOracle = IUSDPriceOracle(_usdOracle);
        relativeOracle = IRelativePriceOracle(_relativeOracle);
        relativeEpsilon = INITIAL_RELATIVE_EPSILON;
        wethAddress = _wethAddress;
    }

    function setUSDOracle(address _usdOracle) external governanceOnly {
        usdOracle = IUSDPriceOracle(_usdOracle);
        emit USDOracleUpdated(_usdOracle);
    }

    function setRelativeOracle(address _relativeOracle) external governanceOnly {
        relativeOracle = IRelativePriceOracle(_relativeOracle);
        emit RelativeOracleUpdated(_relativeOracle);
    }

    function addSignedPriceSource(address _signedAssetToAdd) external governanceOnly {
        trustedSignerPriceOracles.add(_signedAssetToAdd);
        emit TrustedSignerOracleAdded(_signedAssetToAdd);
    }

    function removeSignedPriceSource(address _signedAssetToRemove) external governanceOnly {
        trustedSignerPriceOracles.remove(_signedAssetToRemove);
        emit TrustedSignerOracleRemoved(_signedAssetToRemove);
    }

    function listSignedPriceSource() external view returns (address[] memory) {
        return trustedSignerPriceOracles.values();
    }

    function addQuoteAssetsForPriceLevelTwap(address _quoteAssetToAdd) external governanceOnly {
        quoteAssetsForPriceLevelTWAPS.add(_quoteAssetToAdd);
        emit PriceLevelTWAPQuoteAssetAdded(_quoteAssetToAdd);
    }

    function listQuoteAssetsForPriceLevelTwap() external view returns (address[] memory) {
        return quoteAssetsForPriceLevelTWAPS.values();
    }

    function removeQuoteAssetsForPriceLevelTwap(address _quoteAssetToRemove)
        external
        governanceOnly
    {
        quoteAssetsForPriceLevelTWAPS.remove(_quoteAssetToRemove);
        emit PriceLevelTWAPQuoteAssetRemoved(_quoteAssetToRemove);
    }

    function addAssetForRelativePriceCheck(address assetToAdd) external governanceOnly {
        assetsForRelativePriceCheck.add(assetToAdd);
        emit AssetForRelativePriceCheckAdded(assetToAdd);
    }

    function listAssetForRelativePriceCheck() external view returns (address[] memory) {
        return assetsForRelativePriceCheck.values();
    }

    function removeAssetForRelativePriceCheck(address assetToRemove) external governanceOnly {
        assetsForRelativePriceCheck.remove(assetToRemove);
        emit AssetForRelativePriceCheckRemoved(assetToRemove);
    }

    function batchRelativePriceCheck(address[] memory tokenAddresses, uint256[] memory prices)
        internal
        view
        returns (uint256[] memory)
    {
        uint256[] memory priceLevelTwaps = new uint256[](
            tokenAddresses.length * quoteAssetsForPriceLevelTWAPS.length()
        );

        uint256 k;
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            bool couldCheck = false;

            for (uint256 j = 0; j < assetsForRelativePriceCheck.length(); j++) {
                address assetForCheck = assetsForRelativePriceCheck.at(j);
                if (
                    tokenAddresses[i] == assetForCheck ||
                    !relativeOracle.isPairSupported(tokenAddresses[i], assetForCheck)
                ) {
                    continue;
                }

                uint256 relativePrice = relativeOracle.getRelativePrice(
                    tokenAddresses[i],
                    assetForCheck
                );

                if (
                    tokenAddresses[i] == wethAddress &&
                    quoteAssetsForPriceLevelTWAPS.contains(assetForCheck)
                ) {
                    priceLevelTwaps[k] = relativePrice;
                    k++;
                } else if (
                    assetForCheck == wethAddress &&
                    quoteAssetsForPriceLevelTWAPS.contains(tokenAddresses[i])
                ) {
                    priceLevelTwaps[k] = FixedPoint.ONE.divDown(relativePrice);
                    k++;
                }

                uint256 assetForCheckPrice = _findPrice(assetForCheck, tokenAddresses, prices);
                _ensureRelativePriceConsistency(prices[i], assetForCheckPrice, relativePrice);

                couldCheck = true;
                break;
            }

            require(couldCheck, Errors.ASSET_NOT_SUPPORTED);
        }

        uint256[] memory foundTwaps = new uint256[](k);
        for (uint256 i = 0; i < k; i++) {
            foundTwaps[i] = priceLevelTwaps[i];
        }

        return foundTwaps;
    }

    /// @inheritdoc IUSDPriceOracle
    function getPriceUSD(address tokenAddress) public view override returns (uint256) {
        address[] memory tokenAddresses = new address[](1);
        tokenAddresses[0] = tokenAddress;
        uint256[] memory prices = getPricesUSD(tokenAddresses);
        return prices[0];
    }

    /// @inheritdoc IUSDBatchPriceOracle
    function getPricesUSD(address[] memory tokenAddresses)
        public
        view
        override
        returns (uint256[] memory)
    {
        (uint256[] memory prices, , , ) = getPricesUSDWithMetadata(tokenAddresses);
        return prices;
    }

    function getPricesUSDWithMetadata(address[] memory tokenAddresses)
        public
        view
        returns (
            uint256[] memory,
            uint256,
            uint256[] memory,
            uint256[] memory
        )
    {
        require(tokenAddresses.length > 0, Errors.INVALID_ARGUMENT);

        uint256[] memory prices = new uint256[](tokenAddresses.length);

        /// Will start with this being the WETH/USD price, this can be modified later if desired.
        uint256 priceLevel;

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            prices[i] = usdOracle.getPriceUSD(tokenAddresses[i]);
            if (tokenAddresses[i] == wethAddress) {
                priceLevel = prices[i];
            }
        }

        if (priceLevel == 0) {
            priceLevel = usdOracle.getPriceUSD(wethAddress);
        }

        uint256[] memory priceLevelTwaps = batchRelativePriceCheck(tokenAddresses, prices);

        uint256 numberOfTrustedSignerOracles = trustedSignerPriceOracles.length();
        uint256[] memory signedPrices = new uint256[](numberOfTrustedSignerOracles);

        for (uint256 i = 0; i < numberOfTrustedSignerOracles; i++) {
            IUSDPriceOracle oracle = IUSDPriceOracle(trustedSignerPriceOracles.at(i));
            signedPrices[i] = oracle.getPriceUSD(wethAddress);
        }

        _checkPriceLevel(priceLevel, signedPrices, priceLevelTwaps);

        return (prices, priceLevel, signedPrices, priceLevelTwaps);
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

    function _findPrice(
        address target,
        address[] memory tokenAddresses,
        uint256[] memory prices
    ) internal view returns (uint256) {
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            if (tokenAddresses[i] == target) {
                return prices[i];
            }
        }
        return usdOracle.getPriceUSD(target);
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
        uint256 minTWAP;
        if (twapPrices.length == 0) {
            return _median(signedPrices);
        } else {
            minTWAP = _computeMinOrSecondMin(twapPrices);
            uint256[] memory prices = new uint256[](signedPrices.length + 1);
            prices[prices.length - 1] = minTWAP;
            for (uint256 i = 0; i < prices.length - 1; i++) {
                prices[i] = signedPrices[i];
            }
            return _median(prices);
        }
    }
}
