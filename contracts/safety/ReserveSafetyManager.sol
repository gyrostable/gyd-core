// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../auth/Governable.sol";
import "../../libraries/DataTypes.sol";
import "../../libraries/FixedPoint.sol";
import "../../interfaces/IVaultManager.sol";
import "../../interfaces/IAssetRegistry.sol";
import "../../interfaces/IGyroVault.sol";
import "../../interfaces/balancer/IVault.sol";
import "../../libraries/Errors.sol";
import "../../interfaces/ISafetyCheck.sol";

contract ReserveSafetyManager is Governable, ISafetyCheck {
    using FixedPoint for uint256;

    uint256 public maxAllowedVaultDeviation;
    uint256 public stablecoinMaxDeviation;
    uint256 public minTokenPrice;

    IUSDPriceOracle internal priceOracle;
    IAssetRegistry internal assetRegistry;
    IVaultManager internal vaultManager;

    /// @notice a stablecoin should be equal to 1 USD
    uint256 public constant STABLECOIN_IDEAL_PRICE = 1e18;

    constructor(
        uint256 _maxAllowedVaultDeviation,
        uint256 _stablecoinMaxDeviation,
        uint256 _minTokenPrice,
        IUSDPriceOracle _priceOracle,
        IAssetRegistry _assetRegistry,
        IVaultManager _vaultManager
    ) {
        maxAllowedVaultDeviation = _maxAllowedVaultDeviation;
        stablecoinMaxDeviation = _stablecoinMaxDeviation;
        minTokenPrice = _minTokenPrice;
        priceOracle = _priceOracle;
        assetRegistry = _assetRegistry;
        vaultManager = _vaultManager;
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
            total += amountInUSD;
        }

        if (total == 0) {
            return (weights, total);
        }

        for (uint256 i = 0; i < amounts.length; i++) {
            weights[i] = amounts[i].mulDown(prices[i]).divDown(total);
        }

        return (weights, total);
    }

    /// @notice checks for all vaults whether if a particular vault contains a stablecoin that is off its peg,
    /// whether the proposed change to the vault would be reducing the weight of the vault with the failed asset (as desired).
    /// @param metaData an metadata struct containing all the vault information. Must be fully updated with the price
    /// safety and epsilon data.
    /// @return bool of whether all vaults exhibit this weight decreasing behavior
    function _vaultWeightWithOffPegFalls(DataTypes.Metadata memory metaData)
        internal
        pure
        returns (bool)
    {
        for (uint256 i; i < metaData.vaultMetadata.length; i++) {
            DataTypes.VaultMetadata memory vaultData = metaData.vaultMetadata[i];

            if (vaultData.allStablecoinsOnPeg) {
                continue;
            }

            if ((vaultData.resultingWeight >= vaultData.currentWeight) && (metaData.mint)) {
                return false;
            }
        }

        return true;
    }

    function isRedeemFeasible(DataTypes.Order memory order) internal pure returns (bool) {
        for (uint256 i = 0; i < order.vaultsWithAmount.length; i++) {
            if (
                order.vaultsWithAmount[i].vaultInfo.reserveBalance <
                order.vaultsWithAmount[i].amount
            ) {
                return false;
            }
        }

        return true;
    }

    /// @notice this function takes an order struct and builds the metadata struct, for use in this contract.
    /// @param order an order struct received by the Reserve Safety Manager contract
    /// @return metaData object
    function _buildMetaData(DataTypes.Order memory order)
        internal
        pure
        returns (DataTypes.Metadata memory metaData)
    {
        metaData.vaultMetadata = new DataTypes.VaultMetadata[](order.vaultsWithAmount.length);

        uint256[] memory idealWeights = _calculateIdealWeights(vaultsInfo);
        uint256[] memory currentAmounts = new uint256[](vaultsInfo.length);
        uint256[] memory resultingAmounts = new uint256[](vaultsInfo.length);
        uint256[] memory prices = new uint256[](vaultsInfo.length);

        for (uint256 i = 0; i < vaultsInfo.length; i++) {
            currentAmounts[i] = vaultsInfo[i].reserveBalance;
            metaData.mint = order.mint;

            if (singleVaultOperation) {
                if (vaultsInfo[i].vault == order.vaultsWithAmount[0].vaultInfo.vault) {
                    if (order.mint) {
                        resultingAmounts[i] = currentAmounts[i] + order.vaultsWithAmount[0].amount;
                    } else {
                        resultingAmounts[i] = currentAmounts[i] - order.vaultsWithAmount[0].amount;
                    }
                } else {
                    resultingAmounts[i] = currentAmounts[i];
                }
            } else {
                if (order.mint) {
                    resultingAmounts[i] = currentAmounts[i] + order.vaultsWithAmount[i].amount;
                } else {
                    resultingAmounts[i] = currentAmounts[i] - order.vaultsWithAmount[i].amount;
                }
            }

            metaData.vaultMetadata[i].vault = vaultsInfo[i].vault;
            metaData.vaultMetadata[i].price = vaultsInfo[i].price;
            prices[i] = vaultsInfo[i].price;
        }

        (uint256[] memory currentWeights, uint256 currentUSDValue) = _calculateWeightsAndTotal(
            currentAmounts,
            prices
        );

        (uint256[] memory resultingWeights, ) = _calculateWeightsAndTotal(resultingAmounts, prices);

        // treat 0 inputs/outputs as proportional changes
        if (currentUSDValue == 0) {
            currentWeights = idealWeights;
        }

        for (uint256 i = 0; i < order.vaultsWithAmount.length; i++) {
            metaData.vaultMetadata[i].idealWeight = idealWeights[i];
            metaData.vaultMetadata[i].currentWeight = currentWeights[i];
            metaData.vaultMetadata[i].resultingWeight = resultingWeights[i];
        }
    }

    /// @notice given input metadata, updates it with the information about whether the vault would remain within
    /// an acceptable band (+/- epsilon) around the ideal weight for the vault.
    /// @param metaData a metadata struct containing all the vault information.
    function _updateMetaDataWithEpsilonStatus(DataTypes.Metadata memory metaData) internal view {
        metaData.allVaultsWithinEpsilon = true;

        for (uint256 i = 0; i < metaData.vaultMetadata.length; i++) {
            DataTypes.VaultMetadata memory vaultData = metaData.vaultMetadata[i];
            uint256 scaledEpsilon = vaultData.idealWeight.mulUp(maxAllowedVaultDeviation);
            bool withinEpsilon = vaultData.idealWeight.absSub(vaultData.resultingWeight) <=
                scaledEpsilon;

            metaData.vaultMetadata[i].vaultWithinEpsilon = withinEpsilon;

            if (!withinEpsilon) {
                metaData.allVaultsWithinEpsilon = false;
            }
        }
    }

    /// @notice given input vaultMetadata, updates it with the information about whether the vault contains assets
    /// with safe prices. For a stablecoin, safe means the asset is sufficiently close to the peg. For a
    /// vault consisting of entirely non-stablecoin assets, this means that all of the prices are not 'dust',
    /// to avoid numerical error.
    /// @param vaultMetadata a VaultMetadata struct containing information for a particular vault.
    function _updateVaultWithPriceSafety(DataTypes.VaultMetadata memory vaultMetadata)
        internal
        view
    {
        IERC20[] memory tokens = IGyroVault(vaultMetadata.vault).getTokens();

        vaultMetadata.allStablecoinsOnPeg = true;
        vaultMetadata.allTokenPricesLargeEnough = false;
        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenAddress = address(tokens[i]);
            uint256 tokenPrice = priceOracle.getPriceUSD(tokenAddress);

            if (assetRegistry.isAssetStable(tokenAddress)) {
                vaultMetadata.allTokenPricesLargeEnough = true;
                if (tokenPrice.absSub(STABLECOIN_IDEAL_PRICE) > stablecoinMaxDeviation) {
                    vaultMetadata.allStablecoinsOnPeg = false;
                }
            } else if (tokenPrice >= minTokenPrice) {
                vaultMetadata.allTokenPricesLargeEnough = true;
            }
        }
    }

    /// @notice given input metadata, updates it with the information about whether all vaults contains assets with
    /// safe prices as determined by the _updateVaultWithPriceSafety function.
    /// @param metaData a metadata struct containing all the vault information.
    function _updateMetadataWithPriceSafety(DataTypes.Metadata memory metaData) internal view {
        metaData.allStablecoinsAllVaultsOnPeg = true;
        metaData.allVaultsUsingLargeEnoughPrices = true;
        for (uint256 i = 0; i < metaData.vaultMetadata.length; i++) {
            DataTypes.VaultMetadata memory vaultData = metaData.vaultMetadata[i];
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
    /// @return bool equal to true if for any pool that is outside of epsilon, the weight after the mint/redeem will
    /// be closer to the ideal weight than the current weight is, i.e., the operation promotes rebalancing.
    function _safeToExecuteOutsideEpsilon(DataTypes.Metadata memory metaData)
        internal
        pure
        returns (bool)
    {
        //Check that amount above maxAllowedVaultDeviation is decreasing
        //Check that unhealthy pools have input weight below ideal weight
        //If both true, then mint
        //note: should always be able to mint at the ideal weights!

        for (uint256 i; i < metaData.vaultMetadata.length; i++) {
            DataTypes.VaultMetadata memory vaultMetadata = metaData.vaultMetadata[i];

            if (vaultMetadata.vaultWithinEpsilon) {
                continue;
            }

            uint256 distanceResultingToIdeal = vaultMetadata.resultingWeight.absSub(
                vaultMetadata.idealWeight
            );
            uint256 distanceCurrentToIdeal = vaultMetadata.currentWeight.absSub(
                vaultMetadata.idealWeight
            );

            if (distanceResultingToIdeal >= distanceCurrentToIdeal) {
                return false;
            }
        }

        return true;
    }

    /// @inheritdoc ISafetyCheck
    function isMintSafe(DataTypes.Order memory order) public view returns (string memory) {
        DataTypes.Metadata memory metaData;
        metaData = _buildMetaData(order);

        _updateMetadataWithPriceSafety(metaData);
        _updateMetaDataWithEpsilonStatus(metaData);

        if (!metaData.allVaultsUsingLargeEnoughPrices) {
            return Errors.TOKEN_PRICES_TOO_SMALL;
        }

        if (metaData.allVaultsWithinEpsilon) {
            if (metaData.allStablecoinsAllVaultsOnPeg) {
                return "";
            } else if (_vaultWeightWithOffPegFalls(metaData)) {
                return "";
            }
        } else if (
            _safeToExecuteOutsideEpsilon(metaData) && _vaultWeightWithOffPegFalls(metaData)
        ) {
            return "";
        }

        return Errors.NOT_SAFE_TO_MINT;
    }

    /// @inheritdoc ISafetyCheck
    function isRedeemSafe(DataTypes.Order memory order) public view returns (string memory) {
        if (!isRedeemFeasible(order)) {
            return Errors.TRYING_TO_REDEEM_MORE_THAN_VAULT_CONTAINS;
        }

        DataTypes.Metadata memory metaData;

        metaData = _buildMetaData(order);

        _updateMetadataWithPriceSafety(metaData);
        _updateMetaDataWithEpsilonStatus(metaData);

        if (!metaData.allVaultsUsingLargeEnoughPrices) {
            return Errors.TOKEN_PRICES_TOO_SMALL;
        }

        if (metaData.allVaultsWithinEpsilon) {
            return "";
        } else if (_safeToExecuteOutsideEpsilon(metaData)) {
            return "";
        }

        return Errors.NOT_SAFE_TO_REDEEM;
    }

    /// @inheritdoc ISafetyCheck
    function checkAndPersistMint(DataTypes.Order memory order)
        external
        view
        returns (string memory)
    {
        return isMintSafe(order);
    }

    /// @inheritdoc ISafetyCheck
    function checkAndPersistRedeem(DataTypes.Order memory order)
        external
        view
        returns (string memory)
    {
        return isRedeemSafe(order);
    }
}
