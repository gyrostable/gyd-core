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
}
