// SPDX-License-Identifier: for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>. 
pragma solidity ^0.8.4;

import "../../interfaces/oracles/IUSDPriceOracle.sol";
import "../../interfaces/oracles/IUSDBatchPriceOracle.sol";
import "../../interfaces/oracles/IRelativePriceOracle.sol";
import "../../interfaces/oracles/IBatchVaultPriceOracle.sol";
import "../../libraries/Errors.sol";
import "../../libraries/FixedPoint.sol";

contract MockPriceOracle is
    IUSDPriceOracle,
    IUSDBatchPriceOracle,
    IRelativePriceOracle,
    IBatchVaultPriceOracle
{
    using FixedPoint for uint256;

    mapping(address => uint256) internal usdPrices;
    mapping(address => mapping(address => uint256)) internal relativePrices;

    /// @inheritdoc IUSDPriceOracle
    function getPriceUSD(address baseAsset) public view returns (uint256) {
        uint256 cachedPrice = usdPrices[baseAsset];
        require(cachedPrice != 0, Errors.ASSET_NOT_SUPPORTED);
        return cachedPrice;
    }

    /// @inheritdoc IUSDBatchPriceOracle
    function getPricesUSD(address[] memory baseAssets)
        external
        view
        returns (uint256[] memory prices)
    {
        prices = new uint256[](baseAssets.length);
        for (uint256 i = 0; i < baseAssets.length; i++) {
            prices[i] = getPriceUSD(baseAssets[i]);
        }
    }

    /// @inheritdoc IBatchVaultPriceOracle
    function fetchPricesUSD(DataTypes.VaultInfo[] memory vaultsInfo)
        external
        view
        returns (DataTypes.VaultInfo[] memory)
    {
        for (uint256 i = 0; i < vaultsInfo.length; i++) {
            vaultsInfo[i].price = getPriceUSD(vaultsInfo[i].vault);
            for (uint256 j = 0; j < vaultsInfo[i].pricedTokens.length; j++) {
                vaultsInfo[i].pricedTokens[j].price = getPriceUSD(
                    vaultsInfo[i].pricedTokens[j].tokenAddress
                );
            }
        }
        return vaultsInfo;
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
