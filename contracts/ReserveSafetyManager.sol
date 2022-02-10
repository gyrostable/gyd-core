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

    uint256 private epsilon;
    uint256 private stablecoinMaxDeviation;
    address private balancerVaultAddress;
    address private priceOracleAddress;
    address private assetRegistryAddress;

    struct MetaData {
        uint256[] idealWeights;
        uint256[] currentWeights;
        uint256[] resultingWeights;
        uint256[] deltaWeights;
        uint256[] prices;
        uint256 valueinUSDDeltas;
    }

    /// @notice a stablecoin should be equal to 1 USD
    uint256 public constant STABLECOIN_IDEAL_PRICE = 1e18;

    constructor(uint256 _maxAllowedVaultDeviation) {
        epsilon = _maxAllowedVaultDeviation;
    }

    function getVaultMaxDeviation() external view returns (uint256) {
        return epsilon;
    }

    function setVaultMaxDeviation(uint256 _maxAllowedVaultDeviation) external governanceOnly {
        epsilon = _maxAllowedVaultDeviation;
    }

    function _calculateWeightsAndTotal(uint256[] memory amounts, uint256[] memory prices)
        internal
        pure
        returns (uint256[] memory, uint256)
    {
        require(amounts.length == prices.length, Errors.AMOUNT_AND_PRICE_LENGTH_DIFFER);
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
        metaData.idealWeights = _calculateImpliedPoolWeights(vaultsWithAmount);

        uint256[] memory currentAmounts;
        uint256[] memory deltaAmounts;
        uint256[] memory resultingAmounts;
        uint256[] memory prices;
        uint256 valueinUSDDeltas;
        uint256 currentUSDValue;

        for (uint256 i = 0; i < vaultsWithAmount.length; i++) {
            currentAmounts[i] = vaultsWithAmount[i].vaultInfo.reserveBalance;
            deltaAmounts[i] = vaultsWithAmount[i].amount;

            if (vaultsWithAmount[i].mint) {
                resultingAmounts[i] = currentAmounts[i] + deltaAmounts[i];
            } else {
                resultingAmounts[i] = currentAmounts[i] - deltaAmounts[i];
            }

            prices[i] = vaultsWithAmount[i].vaultInfo.price;
        }

        (metaData.currentWeights, currentUSDValue) = _calculateWeightsAndTotal(
            currentAmounts,
            prices
        );

        (metaData.deltaWeights, valueinUSDDeltas) = _calculateWeightsAndTotal(deltaAmounts, prices);

        (metaData.resultingWeights, ) = _calculateWeightsAndTotal(resultingAmounts, prices);

        if (currentUSDValue == 0) {
            metaData.currentWeights = metaData.idealWeights;
        }

        if (metaData.valueinUSDDeltas == 0) {
            metaData.deltaWeights = metaData.idealWeights;
        }

        metaData.valueinUSDDeltas = valueinUSDDeltas;
    }

    function _calculateImpliedPoolWeights(VaultWithAmount[] memory vaultsWithAmount)
        internal
        pure
        returns (uint256[] memory)
    {
        // order of prices must be same as order of poolProperties
        uint256[] memory impliedIdealWeights = new uint256[](vaultsWithAmount.length);
        uint256[] memory weightedReturns = new uint256[](vaultsWithAmount.length);

        uint256 returnsSum;

        for (uint256 i = 0; i < vaultsWithAmount.length; i++) {
            weightedReturns[i] = (vaultsWithAmount[i].vaultInfo.price)
                .divDown(vaultsWithAmount[i].vaultInfo.persistedMetadata.initialPrice)
                .mulDown(vaultsWithAmount[i].vaultInfo.persistedMetadata.initialWeight);
            returnsSum = returnsSum + weightedReturns[i];
        }

        for (uint256 i = 0; i < vaultsWithAmount.length; i++) {
            impliedIdealWeights[i] = weightedReturns[i].divDown(returnsSum);
        }

        return impliedIdealWeights;
    }

    function _checkVaultsWithinEpsilon(MetaData memory metaData)
        internal
        view
        returns (bool, bool[] memory)
    {
        bool allVaultsWithinEpsilon = true;
        bool[] memory vaultsWithinEpsilon = new bool[](metaData.prices.length);

        for (uint256 i = 0; i < metaData.prices.length; i++) {
            bool withinEpsilon = (metaData.idealWeights[i]).absSub(metaData.resultingWeights[i]) <=
                epsilon;

            vaultsWithinEpsilon[i] = withinEpsilon;

            if (!withinEpsilon) {
                allVaultsWithinEpsilon = false;
            }
        }

        return (allVaultsWithinEpsilon, vaultsWithinEpsilon);
    }

    /// @dev stablecoinPrice must be scaled to 10^18
    function _isStablecoinCloseToPeg(uint256 stablecoinPrice) internal view returns (bool) {
        return stablecoinPrice.absSub(STABLECOIN_IDEAL_PRICE) <= stablecoinMaxDeviation;
    }

    function _individualStablecoinInspector(VaultWithAmount memory vaultWithAmount)
        internal
        view
        returns (bool, bool)
    {
        IVault balVault = IVault(balancerVaultAddress);
        IUSDPriceOracle priceOracle = IUSDPriceOracle(priceOracleAddress);
        IAssetRegistry assetRegistry = IAssetRegistry(assetRegistryAddress);

        (IERC20[] memory tokens, , ) = balVault.getPoolTokens(
            vaultWithAmount.vaultInfo.persistedMetadata.underlyingPoolId
        );

        bool allStablecoinsOnPeg = true;
        bool allStablecoinsOffPeg = false;

        uint256 numberOfStablecoinsInPool;
        uint256 numberOfStablecoinsOffPeg;
        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenAddress = address(tokens[i]);

            if (!assetRegistry.isAssetStable(tokenAddress)) {
                continue;
            }

            numberOfStablecoinsInPool = numberOfStablecoinsInPool + 1;

            uint256 stablecoinPrice = priceOracle.getPriceUSD(tokenAddress);

            if (!_isStablecoinCloseToPeg(stablecoinPrice)) {
                allStablecoinsOnPeg = false;
                numberOfStablecoinsOffPeg = numberOfStablecoinsOffPeg + 1;
                continue;
            }
        }

        if (numberOfStablecoinsInPool == numberOfStablecoinsOffPeg) {
            allStablecoinsOffPeg = true;
        }

        return (allStablecoinsOnPeg, allStablecoinsOffPeg);
    }

    function _allVaultsStablecoinInspector(VaultWithAmount[] memory vaultsWithAmount)
        internal
        view
        returns (
            bool,
            bool,
            bool[] memory
        )
    {
        bool allStablecoinsAllVaultsOnPeg = true;
        bool anyVaultHasOnlyOffPegStablecoins = false;
        bool[] memory vaultStablecoinsOnPeg = new bool[](vaultsWithAmount.length);

        for (uint256 i; i < vaultsWithAmount.length; i++) {
            (bool allStablecoinsOnPeg, bool allStablecoinsOffPeg) = _individualStablecoinInspector(
                vaultsWithAmount[i]
            );
            if (!allStablecoinsOnPeg) {
                allStablecoinsAllVaultsOnPeg = false;
            }
            if (allStablecoinsOffPeg) {
                anyVaultHasOnlyOffPegStablecoins = true;
            }
            vaultStablecoinsOnPeg[i] = allStablecoinsOnPeg;
        }

        return (
            allStablecoinsAllVaultsOnPeg,
            anyVaultHasOnlyOffPegStablecoins,
            vaultStablecoinsOnPeg
        );
    }

    function _checkUnhealthyMovesToIdeal(
        MetaData memory metaData,
        bool[] memory vaultStablecoinsOnPeg
    ) internal pure returns (bool) {
        for (uint256 i; i < metaData.prices.length; i++) {
            if (vaultStablecoinsOnPeg[i]) {
                continue;
            }

            if (metaData.deltaWeights[i] > metaData.idealWeights[i]) {
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
        //Check that amount above epsilon is decreasing
        //Check that unhealthy pools have input weight below ideal weight
        //If both true, then mint
        //note: should always be able to mint at the ideal weights!
        for (uint256 i; i < vaultsWithinEpsilon.length; i++) {
            if (!(vaultStablecoinsOnPeg[i])) {
                if (metaData.deltaWeights[i] > metaData.idealWeights[i]) {
                    return false;
                }
            }

            if (!vaultsWithinEpsilon[i]) {
                // check if resultingWeights[i] is closer to _idealWeights[i] than _currentWeights[i]
                uint256 distanceResultingToIdeal = metaData.resultingWeights[i].absSub(
                    metaData.idealWeights[i]
                );
                uint256 distanceCurrentToIdeal = metaData.currentWeights[i].absSub(
                    metaData.idealWeights[i]
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
        external
        view
        returns (string memory)
    {
        MetaData memory metaData = _buildMetaData(vaultsWithAmount);

        (
            bool allStablecoinsAllVaultsOnPeg,
            bool anyVaultHasOnlyOffPegStablecoins,
            bool[] memory vaultStablecoinsOnPeg
        ) = _allVaultsStablecoinInspector(vaultsWithAmount);

        (
            bool allVaultsWithinEpsilon,
            bool[] memory vaultsWithinEpsilon
        ) = _checkVaultsWithinEpsilon(metaData);

        if (anyVaultHasOnlyOffPegStablecoins) {
            return Errors.A_VAULT_HAS_ALL_STABLECOINS_OFF_PEG;
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
            } else {
                if (
                    _safeToMintOutsideEpsilon(metaData, vaultsWithinEpsilon, vaultStablecoinsOnPeg)
                ) {
                    return "";
                }
            }
        }
        return Errors.NOT_SAFE_TO_MINT;
    }

    /// @inheritdoc ISafetyCheck
    function isRedeemSafe(VaultWithAmount[] memory vaultsWithAmount)
        external
        view
        returns (string memory)
    {
        MetaData memory metaData = _buildMetaData(vaultsWithAmount);

        (
            bool allVaultsWithinEpsilon,
            bool[] memory vaultsWithinEpsilon
        ) = _checkVaultsWithinEpsilon(metaData);

        (, bool anyVaultHasOnlyOffPegStablecoins, ) = _allVaultsStablecoinInspector(
            vaultsWithAmount
        );

        if (anyVaultHasOnlyOffPegStablecoins) {
            return Errors.A_VAULT_HAS_ALL_STABLECOINS_OFF_PEG;
        }

        if (allVaultsWithinEpsilon) {
            return "";
        }

        for (uint256 i = 0; i < vaultsWithAmount.length; i++) {
            if (vaultsWithinEpsilon[i]) {
                continue;
            }

            uint256 distanceResultingToIdeal = metaData.resultingWeights[i].absSub(
                metaData.idealWeights[i]
            );
            uint256 distanceCurrentToIdeal = metaData.currentWeights[i].absSub(
                metaData.idealWeights[i]
            );

            if (distanceResultingToIdeal >= distanceCurrentToIdeal) {
                return Errors.NOT_SAFE_TO_REDEEM;
            }
        }
        return "";
    }

    // /// @inheritdoc ISafetyCheck
    // function checkAndPersistMint(VaultWithAmount[] memory vaultsWithAmount)
    //     external
    //     returns (string memory);

    // /// @inheritdoc ISafetyCheck
    // function checkAndPersistRedeem(VaultWithAmount[] memory vaultsWithAmount)
    //     external
    //     returns (string memory);
}
