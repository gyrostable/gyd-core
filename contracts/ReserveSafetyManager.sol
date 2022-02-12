// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./auth/Governable.sol";
import "../libraries/DataTypes.sol";
import "../libraries/FixedPoint.sol";
import "../interfaces/IVaultManager.sol";
import "../interfaces/IAssetRegistry.sol";
import "../interfaces/balancer/IVault.sol";
import "../libraries/Errors.sol";
import "../interfaces/ISafetyCheck.sol";

contract ReserveSafetyManager is ISafetyCheck, Governable {
    using FixedPoint for uint256;

    uint256 public maxallowedVaultDeviation; // Should be in basis points, e.g. 5% would be 500 bps
    uint256 public stablecoinMaxDeviation;
    uint256 public minTokenPrice;

    IVault internal balancerVault;
    IUSDPriceOracle internal priceOracle;
    IAssetRegistry internal assetRegistry;

    struct VaultData {
        bytes32 underlyingPoolId;
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
        VaultData[] vaultMetadata;
        bool allVaultsWithinEpsilon;
        bool allStablecoinsAllVaultsOnPeg;
        bool allVaultsUsingLargeEnoughPrices;
    }

    /// @notice a stablecoin should be equal to 1 USD
    uint256 public constant STABLECOIN_IDEAL_PRICE = 1e18;

    constructor(
        uint256 _maxAllowedVaultDeviation,
        uint256 _stablecoinMaxDeviation,
        uint256 _minTokenPrice,
        IVault _balancerVault,
        IUSDPriceOracle _priceOracle,
        IAssetRegistry _assetRegistry
    ) {
        maxallowedVaultDeviation = _maxAllowedVaultDeviation;
        stablecoinMaxDeviation = _stablecoinMaxDeviation;
        minTokenPrice = _minTokenPrice;
        balancerVault = _balancerVault;
        priceOracle = _priceOracle;
        assetRegistry = _assetRegistry;
    }

    function setVaultMaxDeviation(uint256 _maxAllowedVaultDeviation) external governanceOnly {
        maxallowedVaultDeviation = _maxAllowedVaultDeviation;
    }

    function setMinTokenPrice(uint256 _minTokenPrice) external governanceOnly {
        minTokenPrice = _minTokenPrice;
    }

    function setStablecoinMaxDeviation(uint256 _stablecoinMaxDeviation) external governanceOnly {
        stablecoinMaxDeviation = _stablecoinMaxDeviation;
    }

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

    function _buildMetaData(VaultWithAmount[] memory vaultsWithAmount)
        internal
        pure
        returns (MetaData memory metaData)
    {
        metaData.vaultMetadata = new VaultData[](vaultsWithAmount.length);

        uint256[] memory idealWeights = _calculateIdealWeights(vaultsWithAmount);
        uint256[] memory currentAmounts = new uint256[](vaultsWithAmount.length);
        uint256[] memory deltaAmounts = new uint256[](vaultsWithAmount.length);
        uint256[] memory resultingAmounts = new uint256[](vaultsWithAmount.length);
        uint256[] memory prices = new uint256[](vaultsWithAmount.length);

        for (uint256 i = 0; i < vaultsWithAmount.length; i++) {
            currentAmounts[i] = vaultsWithAmount[i].vaultInfo.reserveBalance;
            deltaAmounts[i] = vaultsWithAmount[i].amount;

            if (vaultsWithAmount[i].mint) {
                resultingAmounts[i] = currentAmounts[i] + deltaAmounts[i];
            } else {
                resultingAmounts[i] = currentAmounts[i] - deltaAmounts[i];
            }

            metaData.vaultMetadata[i].price = vaultsWithAmount[i].vaultInfo.price;

            metaData.vaultMetadata[i].underlyingPoolId = vaultsWithAmount[i]
                .vaultInfo
                .persistedMetadata
                .underlyingPoolId;
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

        for (uint256 i = 0; i < vaultsWithAmount.length; i++) {
            metaData.vaultMetadata[i].idealWeight = idealWeights[i];
            metaData.vaultMetadata[i].currentWeight = currentWeights[i];
            metaData.vaultMetadata[i].resultingWeight = resultingWeights[i];
            metaData.vaultMetadata[i].deltaWeight = deltaWeights[i];
        }
    }

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

    function _updateMetaDataWithEpsilonStatus(MetaData memory _metaData)
        internal
        view
        returns (MetaData memory metaData)
    {
        metaData = _metaData;
        metaData.allVaultsWithinEpsilon = true;

        for (uint256 i = 0; i < metaData.vaultMetadata.length; i++) {
            VaultData memory vaultData = metaData.vaultMetadata[i];
            uint256 scaledEpsilon = (vaultData.idealWeight * maxallowedVaultDeviation) / 10000;
            bool withinEpsilon = vaultData.idealWeight.absSub(vaultData.resultingWeight) <=
                scaledEpsilon;

            metaData.vaultMetadata[i].vaultWithinEpsilon = withinEpsilon;

            if (!withinEpsilon) {
                metaData.allVaultsWithinEpsilon = false;
            }
        }
    }

    function _updateVaultWithPriceSafety(VaultData memory _vaultData)
        internal
        view
        returns (VaultData memory vaultData)
    {
        vaultData = _vaultData;

        (IERC20[] memory tokens, , ) = balancerVault.getPoolTokens(vaultData.underlyingPoolId);

        vaultData.allStablecoinsOnPeg = true;
        vaultData.allTokenPricesLargeEnough = true;
        uint256 numberOfTinyTokenPrices;
        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenAddress = address(tokens[i]);
            uint256 tokenPrice = priceOracle.getPriceUSD(tokenAddress);

            if (assetRegistry.isAssetStable(tokenAddress)) {
                if (tokenPrice.absSub(STABLECOIN_IDEAL_PRICE) <= stablecoinMaxDeviation) {
                    vaultData.allStablecoinsOnPeg = false;
                }
            }

            if (tokenPrice < minTokenPrice) {
                numberOfTinyTokenPrices = numberOfTinyTokenPrices + 1;
            }
        }

        if (numberOfTinyTokenPrices == tokens.length) {
            vaultData.allTokenPricesLargeEnough = false;
        }
    }

    function _updateMetadataWithPriceSafety(MetaData memory _metaData)
        internal
        view
        returns (MetaData memory metaData)
    {
        metaData = _metaData;
        metaData.allStablecoinsAllVaultsOnPeg = true;
        metaData.allVaultsUsingLargeEnoughPrices = true;
        for (uint256 i = 0; i < metaData.vaultMetadata.length; i++) {
            VaultData memory newVaultData = _updateVaultWithPriceSafety(metaData.vaultMetadata[i]);
            if (!newVaultData.allStablecoinsOnPeg) {
                metaData.allStablecoinsAllVaultsOnPeg = false;
            }
            if (!newVaultData.allTokenPricesLargeEnough) {
                metaData.allVaultsUsingLargeEnoughPrices = false;
            }
        }
    }

    function _checkAnyOffPegVaultWouldMoveCloserToIdealWeight(MetaData memory metaData)
        internal
        pure
        returns (bool)
    {
        for (uint256 i; i < metaData.vaultMetadata.length; i++) {
            VaultData memory vaultData = metaData.vaultMetadata[i];

            if (vaultData.allStablecoinsOnPeg) {
                continue;
            }

            if (vaultData.deltaWeight > vaultData.idealWeight) {
                return false;
            }
        }

        return true;
    }

    function _safeToExecuteOutsideEpsilon(MetaData memory metaData) internal pure returns (bool) {
        //Check that amount above maxallowedVaultDeviation is decreasing
        //Check that unhealthy pools have input weight below ideal weight
        //If both true, then mint
        //note: should always be able to mint at the ideal weights!

        for (uint256 i; i < metaData.vaultMetadata.length; i++) {
            VaultData memory vaultData = metaData.vaultMetadata[i];

            if ()

            if (!vaultData.allStablecoinsOnPeg) {
                if (vaultData.deltaWeight > vaultData.idealWeight) {
                    return false;
                }
            }

            if (!vaultData.vaultWithinEpsilon) {
                // check if resultingWeights[i] is closer to _idealWeights[i] than _currentWeights[i]
                uint256 distanceResultingToIdeal = vaultData.resultingWeight.absSub(
                    vaultData.idealWeight
                );
                uint256 distanceCurrentToIdeal = vaultData.currentWeight.absSub(
                    vaultData.idealWeight
                );

                if (distanceResultingToIdeal >= distanceCurrentToIdeal) {
                    return false;
                }
            }
        }

        return true;
    }

    /// @inheritdoc ISafetyCheck
    function isMintSafe(VaultWithAmount[] memory vaultsWithAmount)
        public
        view
        returns (string memory)
    {
        MetaData memory metaData = _buildMetaData(vaultsWithAmount);
        MetaData memory metaDataWithPriceInfo = _updateMetadataWithPriceSafety(metaData);
        MetaData memory metaDataFull = _updateMetaDataWithEpsilonStatus(metaDataWithPriceInfo);

        if (!metaDataFull.allVaultsUsingLargeEnoughPrices) {
            return Errors.TOKEN_PRICES_TOO_SMALL;
        }

        if (metaDataFull.allStablecoinsAllVaultsOnPeg) {
            if (metaDataFull.allVaultsWithinEpsilon) {
                return "";
            }
        } else {
            if (metaDataFull.allVaultsWithinEpsilon) {
                if (_checkAnyOffPegVaultWouldMoveCloserToIdealWeight(metaDataFull)) {
                    return "";
                }
            } else if (_safeToExecuteOutsideEpsilon(metaDataFull)) {
                return "";
            }
        }
        return Errors.NOT_SAFE_TO_MINT;
    }

    /// @inheritdoc ISafetyCheck
    function isRedeemSafe(VaultWithAmount[] memory vaultsWithAmount)
        public
        view
        returns (string memory)
    {
        MetaData memory metaData = _buildMetaData(vaultsWithAmount);
        MetaData memory metaDataFull = _updateMetaDataWithEpsilonStatus(metaData);

        if (!metaDataFull.allVaultsUsingLargeEnoughPrices) {
            return Errors.TOKEN_PRICES_TOO_SMALL;
        }

        if (metaDataFull.allVaultsWithinEpsilon) {
            return "";
        } else if (_safeToExecuteOutsideEpsilon(metaDataFull)) {
            return "";
        } else {
            return Errors.NOT_SAFE_TO_REDEEM;
        }
    }

    /// @inheritdoc ISafetyCheck
    function checkAndPersistMint(VaultWithAmount[] memory vaultsWithAmount)
        external
        view
        returns (string memory)
    {
        return isMintSafe(vaultsWithAmount);
    }

    /// @inheritdoc ISafetyCheck
    function checkAndPersistRedeem(VaultWithAmount[] memory vaultsWithAmount)
        external
        view
        returns (string memory)
    {
        return isRedeemSafe(vaultsWithAmount);
    }
}
