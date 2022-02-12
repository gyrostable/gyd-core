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
        uint256 idealWeight;
        uint256 currentWeight;
        uint256 resultingWeight;
        uint256 deltaWeight;
        uint256 price;
    }

    struct MetaData {
        VaultData[] vaultMetadata;
        uint256 valueinUSDDeltas;
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
        }

        // metaData.prices = prices;

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

        if (metaData.valueinUSDDeltas == 0) {
            deltaWeights = idealWeights;
        }

        for (uint256 i = 0; i < vaultsWithAmount.length; i++) {
            metaData.vaultMetadata[i].idealWeight = idealWeights[i];
            metaData.vaultMetadata[i].currentWeight = currentWeights[i];
            metaData.vaultMetadata[i].resultingWeight = resultingWeights[i];
            metaData.vaultMetadata[i].deltaWeight = deltaWeights[i];
        }

        metaData.valueinUSDDeltas = valueinUSDDeltas;
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

    function _checkVaultsWithinEpsilon(MetaData memory metaData)
        internal
        view
        returns (bool, bool[] memory)
    {
        bool allVaultsWithinEpsilon = true;
        bool[] memory vaultsWithinEpsilon = new bool[](metaData.vaultMetadata.length);

        for (uint256 i = 0; i < metaData.vaultMetadata.length; i++) {
            VaultData memory vaultData = metaData.vaultMetadata[i];
            uint256 scaledEpsilon = (vaultData.idealWeight * maxallowedVaultDeviation) / 10000;
            bool withinEpsilon = vaultData.idealWeight.absSub(vaultData.resultingWeight) <=
                scaledEpsilon;

            vaultsWithinEpsilon[i] = withinEpsilon;

            if (!withinEpsilon) {
                allVaultsWithinEpsilon = false;
            }
        }

        return (allVaultsWithinEpsilon, vaultsWithinEpsilon);
    }

    function _individualVaultInspector(VaultWithAmount memory vaultWithAmount)
        internal
        view
        returns (bool, bool)
    {
        (IERC20[] memory tokens, , ) = balancerVault.getPoolTokens(
            vaultWithAmount.vaultInfo.persistedMetadata.underlyingPoolId
        );

        bool allStablecoinsOnPeg = true;
        bool allTokenPricesLargeEnough = true;
        uint256 numberOfTinyTokenPrices;
        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenAddress = address(tokens[i]);
            uint256 tokenPrice = priceOracle.getPriceUSD(tokenAddress);

            if (assetRegistry.isAssetStable(tokenAddress)) {
                if (tokenPrice.absSub(STABLECOIN_IDEAL_PRICE) <= stablecoinMaxDeviation) {
                    allStablecoinsOnPeg = false;
                }
            }

            if (tokenPrice < minTokenPrice) {
                numberOfTinyTokenPrices = numberOfTinyTokenPrices + 1;
            }
        }

        if (numberOfTinyTokenPrices == tokens.length) {
            allTokenPricesLargeEnough = false;
        }

        return (allStablecoinsOnPeg, allTokenPricesLargeEnough);
    }

    function _allVaultsInspector(VaultWithAmount[] memory vaultsWithAmount)
        internal
        view
        returns (
            bool,
            bool[] memory,
            bool,
            bool[] memory
        )
    {
        bool allStablecoinsAllVaultsOnPeg = true;
        bool[] memory vaultStablecoinsOnPeg = new bool[](vaultsWithAmount.length);

        bool allVaultsUsingLargeEnoughPrices = true;
        bool[] memory vaultUsingLargeEnoughPrices = new bool[](vaultsWithAmount.length);

        for (uint256 i = 0; i < vaultsWithAmount.length; i++) {
            (bool allStablecoinsOnPeg, bool allTokenPricesLargeEnough) = _individualVaultInspector(
                vaultsWithAmount[i]
            );
            if (!allStablecoinsOnPeg) {
                allStablecoinsAllVaultsOnPeg = false;
            }
            if (!allTokenPricesLargeEnough) {
                allVaultsUsingLargeEnoughPrices = false;
            }

            vaultStablecoinsOnPeg[i] = allStablecoinsOnPeg;
            vaultUsingLargeEnoughPrices[i] = allTokenPricesLargeEnough;
        }

        return (
            allStablecoinsAllVaultsOnPeg,
            vaultStablecoinsOnPeg,
            allVaultsUsingLargeEnoughPrices,
            vaultUsingLargeEnoughPrices
        );
    }

    function _checkUnhealthyMovesToIdeal(
        MetaData memory metaData,
        bool[] memory vaultStablecoinsOnPeg
    ) internal pure returns (bool) {
        for (uint256 i; i < metaData.vaultMetadata.length; i++) {
            if (vaultStablecoinsOnPeg[i]) {
                continue;
            }
            VaultData memory vaultData = metaData.vaultMetadata[i];

            if (vaultData.deltaWeight > vaultData.idealWeight) {
                return false;
            }
        }

        return true;
    }

    function _safeToMintOutsideEpsilon(
        MetaData memory metaData,
        bool[] memory vaultsWithinEpsilon,
        bool[] memory vaultStablecoinsOnPeg
    ) internal pure returns (bool) {
        //Check that amount above maxallowedVaultDeviation is decreasing
        //Check that unhealthy pools have input weight below ideal weight
        //If both true, then mint
        //note: should always be able to mint at the ideal weights!
        for (uint256 i; i < vaultsWithinEpsilon.length; i++) {
            VaultData memory vaultData = metaData.vaultMetadata[i];
            if (!(vaultStablecoinsOnPeg[i])) {
                if (vaultData.deltaWeight > vaultData.idealWeight) {
                    return false;
                }
            }

            if (!vaultsWithinEpsilon[i]) {
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

        (
            bool allStablecoinsAllVaultsOnPeg,
            bool[] memory vaultStablecoinsOnPeg,
            bool allVaultsUsingLargeEnoughPrices,

        ) = _allVaultsInspector(vaultsWithAmount);

        (
            bool allVaultsWithinEpsilon,
            bool[] memory vaultsWithinEpsilon
        ) = _checkVaultsWithinEpsilon(metaData);

        if (!allVaultsUsingLargeEnoughPrices) {
            return Errors.TOKEN_PRICES_TOO_SMALL;
        }

        if (allStablecoinsAllVaultsOnPeg) {
            if (allVaultsWithinEpsilon) {
                return "";
            }
        } else {
            if (allVaultsWithinEpsilon) {
                if (_checkUnhealthyMovesToIdeal(metaData, vaultStablecoinsOnPeg)) {
                    return "";
                }
            } else if (
                _safeToMintOutsideEpsilon(metaData, vaultsWithinEpsilon, vaultStablecoinsOnPeg)
            ) {
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

        (
            bool allVaultsWithinEpsilon,
            bool[] memory vaultsWithinEpsilon
        ) = _checkVaultsWithinEpsilon(metaData);

        if (allVaultsWithinEpsilon) {
            return "";
        }

        for (uint256 i = 0; i < vaultsWithAmount.length; i++) {
            if (vaultsWithinEpsilon[i]) {
                continue;
            }
            VaultData memory vaultData = metaData.vaultMetadata[i];

            uint256 distanceResultingToIdeal = vaultData.resultingWeight.absSub(
                vaultData.idealWeight
            );
            uint256 distanceCurrentToIdeal = vaultData.currentWeight.absSub(vaultData.idealWeight);

            if (distanceResultingToIdeal >= distanceCurrentToIdeal) {
                return Errors.NOT_SAFE_TO_REDEEM;
            }
        }
        return "";
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
