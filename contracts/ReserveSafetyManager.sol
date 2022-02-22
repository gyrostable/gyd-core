// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./auth/Governable.sol";
import "../libraries/DataTypes.sol";
import "../libraries/FixedPoint.sol";
import "../interfaces/IVaultManager.sol";
import "../interfaces/IAssetRegistry.sol";
import "../interfaces/IGyroVault.sol";
import "../interfaces/balancer/IVault.sol";
import "../libraries/Errors.sol";
import "../interfaces/ISafetyCheck.sol";

contract ReserveSafetyManager is ISafetyCheck, Governable {
    using FixedPoint for uint256;

    uint256 public maxAllowedVaultDeviation;
    uint256 public stablecoinMaxDeviation;
    uint256 public minTokenPrice;

    IUSDPriceOracle internal priceOracle;
    IAssetRegistry internal assetRegistry;

    struct VaultMetadata {
        address vault;
        uint256 idealWeight;
        uint256 currentWeight;
        uint256 resultingWeight;
        uint256 deltaWeight;
        uint256 price;
        bool allStablecoinsOnPeg;
        bool allTokenPricesLargeEnough;
        bool vaultWithinEpsilon;
    }

    struct MetaData {
        VaultMetadata[] vaultMetadata;
        bool allVaultsWithinEpsilon;
        bool allStablecoinsAllVaultsOnPeg;
        bool allVaultsUsingLargeEnoughPrices;
        bool mint;
    }

    /// @notice a stablecoin should be equal to 1 USD
    uint256 public constant STABLECOIN_IDEAL_PRICE = 1e18;

    constructor(
        uint256 _maxAllowedVaultDeviation,
        uint256 _stablecoinMaxDeviation,
        uint256 _minTokenPrice,
        IUSDPriceOracle _priceOracle,
        IAssetRegistry _assetRegistry
    ) {
        maxAllowedVaultDeviation = _maxAllowedVaultDeviation;
        stablecoinMaxDeviation = _stablecoinMaxDeviation;
        minTokenPrice = _minTokenPrice;
        priceOracle = _priceOracle;
        assetRegistry = _assetRegistry;
    }

    function setVaultMaxDeviation(uint256 _maxAllowedVaultDeviation) external governanceOnly {
        maxAllowedVaultDeviation = _maxAllowedVaultDeviation;
    }

    function setMinTokenPrice(uint256 _minTokenPrice) external governanceOnly {
        minTokenPrice = _minTokenPrice;
    }

    function setStablecoinMaxDeviation(uint256 _stablecoinMaxDeviation) external governanceOnly {
        stablecoinMaxDeviation = _stablecoinMaxDeviation;
    }

    /// @notice For given token amounts and token prices, calculates the weight of each token with
    /// respect to the quote price as well as the total value of the basket in terms of the quote price
    /// @param amounts an array of token amounts
    /// @param prices an array of prices
    /// @return (weights, total) where the weights is an array and the total a uint
    function _calculateWeightsAndTotal(uint256[] memory amounts, uint256[] memory prices)
        internal
        pure
        returns (uint256[] memory, uint256)
    {
        uint256[] memory weights = new uint256[](prices.length);
        uint256 total = 0;

        for (uint256 i = 0; i < amounts.length; i++) {
            uint256 amountInUSD = amounts[i].mulDown(prices[i]);
            total = total + amountInUSD;
        }

        if (total == 0) {
            return (weights, total);
        }

        for (uint256 i = 0; i < amounts.length; i++) {
            weights[i] = amounts[i].mulDown(prices[i]).divDown(total);
        }

        return (weights, total);
    }

    /// @notice For a given set of input vaults, calculates the ideal weight the vault should now have,
    /// given (i) the vault's initial weight and (ii) the evolution of prices since the vault's initialization.
    /// @param vaultsWithAmount an array of VaultWithAmountStructs
    /// @return idealWeights an array of the ideal weights
    function _calculateIdealWeights(VaultWithAmount[] memory vaultsWithAmount)
        internal
        pure
        returns (uint256[] memory)
    {
        // order of prices must be same as order of poolProperties
        uint256[] memory idealWeights = new uint256[](vaultsWithAmount.length);
        uint256[] memory weightedReturns = new uint256[](vaultsWithAmount.length);

        uint256 returnsSum;

        for (uint256 i = 0; i < vaultsWithAmount.length; i++) {
            weightedReturns[i] = (vaultsWithAmount[i].vaultInfo.price)
                .divDown(vaultsWithAmount[i].vaultInfo.persistedMetadata.initialPrice)
                .mulDown(vaultsWithAmount[i].vaultInfo.persistedMetadata.initialWeight);
            returnsSum = returnsSum + weightedReturns[i];
        }

        for (uint256 i = 0; i < vaultsWithAmount.length; i++) {
            idealWeights[i] = weightedReturns[i].divDown(returnsSum);
        }

        return idealWeights;
    }

    /// @notice checks for all vaults whether if a particular vault contains a stablecoin that is off its peg,
    /// whether the proposed change to the vault weight is equal to or smaller than the ideal weight, i.e., whether
    /// the operation would be reducing the weight of the vault with the failed asset (as desired).
    /// @param metaData an metadata struct containing all the vault information. Must be fully updated with the price
    /// safety and epsilon data.
    /// @return bool of whether all vaults exhibit this weight decreasing behavior
    function _vaultWeightWithOffPegFalls(MetaData memory metaData) internal pure returns (bool) {
        for (uint256 i; i < metaData.vaultMetadata.length; i++) {
            VaultMetadata memory vaultData = metaData.vaultMetadata[i];

            if (vaultData.allStablecoinsOnPeg) {
                continue;
            }

            if (vaultData.deltaWeight > vaultData.idealWeight) {
                return false;
            }
        }

        return true;
    }

    /// @notice this function takes an order struct and builds the metadata struct, for use in this contract.
    /// @param order an order struct received by the Reserve Safety Manager contract
    /// @return metaData object
    function _buildMetaData(Order memory order) internal pure returns (MetaData memory metaData) {
        metaData.vaultMetadata = new VaultMetadata[](order.vaultsWithAmount.length);

        uint256[] memory idealWeights = _calculateIdealWeights(order.vaultsWithAmount);
        uint256[] memory currentAmounts = new uint256[](order.vaultsWithAmount.length);
        uint256[] memory deltaAmounts = new uint256[](order.vaultsWithAmount.length);
        uint256[] memory resultingAmounts = new uint256[](order.vaultsWithAmount.length);
        uint256[] memory prices = new uint256[](order.vaultsWithAmount.length);

        for (uint256 i = 0; i < order.vaultsWithAmount.length; i++) {
            currentAmounts[i] = order.vaultsWithAmount[i].vaultInfo.reserveBalance;
            deltaAmounts[i] = order.vaultsWithAmount[i].amount;

            metaData.mint = order.mint;
            if (order.mint) {
                resultingAmounts[i] = currentAmounts[i] + deltaAmounts[i];
            } else {
                resultingAmounts[i] = currentAmounts[i] - deltaAmounts[i];
            }

            metaData.vaultMetadata[i].vault = order.vaultsWithAmount[i].vaultInfo.vault;
            metaData.vaultMetadata[i].price = order.vaultsWithAmount[i].vaultInfo.price;
        }

        (uint256[] memory currentWeights, uint256 currentUSDValue) = _calculateWeightsAndTotal(
            currentAmounts,
            prices
        );

        // deltaWeights = weighting of proposed inputs or outputs, not change in weights from resulting to current
        (uint256[] memory deltaWeights, uint256 valueinUSDDeltas) = _calculateWeightsAndTotal(
            deltaAmounts,
            prices
        );

        (uint256[] memory resultingWeights, ) = _calculateWeightsAndTotal(resultingAmounts, prices);

        // treat 0 inputs/outputs as proportional changes
        if (currentUSDValue == 0) {
            currentWeights = idealWeights;
        }

        if (valueinUSDDeltas == 0) {
            deltaWeights = idealWeights;
        }

        for (uint256 i = 0; i < order.vaultsWithAmount.length; i++) {
            metaData.vaultMetadata[i].idealWeight = idealWeights[i];
            metaData.vaultMetadata[i].currentWeight = currentWeights[i];
            metaData.vaultMetadata[i].resultingWeight = resultingWeights[i];
            metaData.vaultMetadata[i].deltaWeight = deltaWeights[i];
        }
    }

    /// @notice given input metadata, updates it with the information about whether the vault would remain within
    /// an acceptable band (+/- epsilon) around the ideal weight for the vault.
    /// @param metaData a metadata struct containing all the vault information.
    function _updateMetaDataWithEpsilonStatus(MetaData memory metaData) internal view {
        metaData.allVaultsWithinEpsilon = true;

        for (uint256 i = 0; i < metaData.vaultMetadata.length; i++) {
            VaultMetadata memory vaultData = metaData.vaultMetadata[i];
            uint256 scaledEpsilon = vaultData.idealWeight.mulUp(maxAllowedVaultDeviation);
            bool withinEpsilon = vaultData.idealWeight.absSub(vaultData.resultingWeight) <=
                scaledEpsilon;

            metaData.vaultMetadata[i].vaultWithinEpsilon = withinEpsilon;

            if (!withinEpsilon) {
                metaData.allVaultsWithinEpsilon = false;
            }
        }
    }

    /// @notice given input _vaultData, updates it with the information about whether the vault contains assets
    /// with safe prices. For a stablecoin, safe means the asset is sufficiently close to the peg. For a
    /// vault consisting of entirely non-stablecoin assets, this means that all of the prices are not 'dust',
    /// to avoid numerical error.
    /// @param vaultData a VaultMetadata struct containing information for a particular vault.
    function _updateVaultWithPriceSafety(VaultMetadata memory vaultData) internal view {
        IERC20[] memory tokens = IGyroVault(vaultData.vault).getTokens();

        vaultData.allStablecoinsOnPeg = true;
        vaultData.allTokenPricesLargeEnough = false;
        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenAddress = address(tokens[i]);
            uint256 tokenPrice = priceOracle.getPriceUSD(tokenAddress);

            if (assetRegistry.isAssetStable(tokenAddress)) {
                if (tokenPrice.absSub(STABLECOIN_IDEAL_PRICE) > stablecoinMaxDeviation) {
                    vaultData.allStablecoinsOnPeg = false;
                }
            } else if (tokenPrice >= minTokenPrice) {
                vaultData.allTokenPricesLargeEnough = true;
            }
        }
    }

    /// @notice given input metadata, updates it with the information about whether all vaults contains assets with
    /// safe prices as determined by the _updateVaultWithPriceSafety function.
    /// @param metaData a metadata struct containing all the vault information.
    function _updateMetadataWithPriceSafety(MetaData memory metaData) internal view {
        metaData.allStablecoinsAllVaultsOnPeg = true;
        metaData.allVaultsUsingLargeEnoughPrices = true;
        for (uint256 i = 0; i < metaData.vaultMetadata.length; i++) {
            VaultMetadata memory vaultData = metaData.vaultMetadata[i];
            _updateVaultWithPriceSafety(vaultData);
            if (!vaultData.allStablecoinsOnPeg) {
                metaData.allStablecoinsAllVaultsOnPeg = false;
            }
            if (!vaultData.allTokenPricesLargeEnough) {
                metaData.allVaultsUsingLargeEnoughPrices = false;
            }
        }
    }

    /// @notice given input metadata,
    /// @param metaData a metadata struct containing all the vault information, updated with price safety and the
    /// status of the vault regarding whether it is within epsilon.

    /// If minting, there are two requirements for this function to return true: (i) that if the stablecoin is off peg,
    /// then the weight of the delta is equal to or less than the ideal weight (and therefore the amount above epsilon is
    /// decreasing) and (ii) for any individual vault that is outside of epsilon, that the resulting weight would be
    /// closer to the ideal weight than the current weight.

    /// If redeeming, then there is a single requirement for this function to return true: that for any vault that is
    /// outside of epsilon, the resulting weight would be closer to the ideal weight than the current weight.
    /// @return bool equal to true if for any pool that is outside of epsilon, the weight after the mint/redeem will
    /// be closer to the ideal weight than the current weight is, i.e., the operation rebalances.
    function _safeToExecuteOutsideEpsilon(MetaData memory metaData) internal pure returns (bool) {
        //Check that amount above maxAllowedVaultDeviation is decreasing
        //Check that unhealthy pools have input weight below ideal weight
        //If both true, then mint
        //note: should always be able to mint at the ideal weights!

        if (metaData.mint && !_vaultWeightWithOffPegFalls(metaData)) {
            return false;
        }

        for (uint256 i; i < metaData.vaultMetadata.length; i++) {
            VaultMetadata memory vaultData = metaData.vaultMetadata[i];

            if (vaultData.vaultWithinEpsilon) {
                continue;
            }

            uint256 distanceResultingToIdeal = vaultData.resultingWeight.absSub(
                vaultData.idealWeight
            );
            uint256 distanceCurrentToIdeal = vaultData.currentWeight.absSub(vaultData.idealWeight);

            if (distanceResultingToIdeal >= distanceCurrentToIdeal) {
                return false;
            }
        }

        return true;
    }

    /// @inheritdoc ISafetyCheck
    function isMintSafe(Order memory order) public view returns (string memory) {
        MetaData memory metaData = _buildMetaData(order);
        _updateMetadataWithPriceSafety(metaData);
        _updateMetaDataWithEpsilonStatus(metaData);

        if (!metaData.allVaultsUsingLargeEnoughPrices) {
            return Errors.TOKEN_PRICES_TOO_SMALL;
        }

        if (metaData.allStablecoinsAllVaultsOnPeg) {
            if (metaData.allVaultsWithinEpsilon) {
                return "";
            }
        } else {
            if (metaData.allVaultsWithinEpsilon) {
                if (_vaultWeightWithOffPegFalls(metaData)) {
                    return "";
                }
            } else if (_safeToExecuteOutsideEpsilon(metaData)) {
                return "";
            }
        }
        return Errors.NOT_SAFE_TO_MINT;
    }

    /// @inheritdoc ISafetyCheck
    function isRedeemSafe(Order memory order) public view returns (string memory) {
        MetaData memory metaData = _buildMetaData(order);
        _updateMetadataWithPriceSafety(metaData);
        _updateMetaDataWithEpsilonStatus(metaData);

        if (!metaData.allVaultsUsingLargeEnoughPrices) {
            return Errors.TOKEN_PRICES_TOO_SMALL;
        }

        if (metaData.allVaultsWithinEpsilon) {
            return "";
        } else if (_safeToExecuteOutsideEpsilon(metaData)) {
            return "";
        } else {
            return Errors.NOT_SAFE_TO_REDEEM;
        }
    }

    /// @inheritdoc ISafetyCheck
    function checkAndPersistMint(Order memory order) external view returns (string memory) {
        return isMintSafe(order);
    }

    /// @inheritdoc ISafetyCheck
    function checkAndPersistRedeem(Order memory order) external view returns (string memory) {
        return isRedeemSafe(order);
    }
}
