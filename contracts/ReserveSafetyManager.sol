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

    struct VaultLocal {
        uint256 idealWeight;
        uint256 preDeltaWeight;
        uint256 postDeltaWeight;
        bool allStablecoinsCloseToPeg;
        bool withinEpsilon;
        bytes32 underlyingPoolId;
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

    function calculateWeightsAndTotal(uint256[] memory amounts, uint256[] memory prices)
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

    function calculateImpliedPoolWeights(VaultWithAmount[] memory vaultsWithAmount)
        internal
        view
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

    function checkVaultsWithinEpsilon(VaultLocal[] memory vaultsLocal)
        internal
        view
        returns (bool, bool[] memory vaultsWithinEpsilon)
    {
        bool allVaultsWithinEpsilon = true;

        for (uint256 i = 0; i < vaultsLocal.length; i++) {
            bool withinEpsilon = (vaultsLocal[i].idealWeight).absSub(
                vaultsLocal[i].postDeltaWeight
            ) <= epsilon;

            vaultsWithinEpsilon[i] = withinEpsilon;

            if (!withinEpsilon) {
                allVaultsWithinEpsilon = false;
            }
        }

        return (allVaultsWithinEpsilon, vaultsWithinEpsilon);
    }

    /// @dev stablecoinPrice must be scaled to 10^18
    function isStablecoinCloseToPeg(uint256 stablecoinPrice) internal view returns (bool) {
        return stablecoinPrice.absSub(STABLECOIN_IDEAL_PRICE) <= stablecoinMaxDeviation;
    }

    function areAllPoolStablecoinsCloseToPeg(bytes32 poolId) public view returns (bool) {
        IVault balVault = IVault(balancerVaultAddress);
        IUSDPriceOracle priceOracle = IUSDPriceOracle(priceOracleAddress);
        IAssetRegistry assetRegistry = IAssetRegistry(assetRegistryAddress);

        (IERC20[] memory tokens, , ) = balVault.getPoolTokens(poolId);

        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenAddress = address(tokens[i]);

            if (!assetRegistry.isAssetStable(tokenAddress)) {
                continue;
            }

            uint256 stablecoinPrice = priceOracle.getPriceUSD(tokenAddress);
            bool isCloseToPeg = isStablecoinCloseToPeg(stablecoinPrice);

            if (!isCloseToPeg) {
                return false;
            }
        }

        return true;
    }

    function vaultStablecoinStatus(VaultLocal[] memory vaultsLocal)
        internal
        view
        returns (bool, VaultLocal[] memory)
    {
        bool allStablecoinsCloseToPeg = true;
        for (uint256 i = 0; i < vaultsLocal.length; i++) {
            vaultsLocal[i].allStablecoinsCloseToPeg = areAllPoolStablecoinsCloseToPeg(
                vaultsLocal[i].underlyingPoolId
            );
            allStablecoinsCloseToPeg = false;
        }
        return (allStablecoinsCloseToPeg, vaultsLocal);
    }

    function checkUnhealthyMovesToIdeal(
        VaultLocal[] memory vaultsLocal,
        uint256[] memory deltaWeights,
        uint256[] memory idealWeights
    ) internal pure returns (bool) {
        for (uint256 i; i < vaultsLocal.length; i++) {
            if (vaultsLocal[i].allStablecoinsCloseToPeg) {
                continue;
            }

            if (deltaWeights[i] > idealWeights[i]) {
                return false;
            }
        }

        return true;
    }

    function safeToMintOutsideEpsilon(
        VaultWithAmount[] memory vaultsWithAmount,
        VaultLocal[] memory vaultsLocal,
        uint256[] memory deltaWeights,
        uint256[] memory idealWeights,
        uint256[] memory currentWeights,
        bool[] memory vaultsWithinEpsilon
    ) internal pure returns (bool) {
        //Check that amount above epsilon is decreasing
        //Check that unhealthy pools have input weight below ideal weight
        //If both true, then mint
        //note: should always be able to mint at the ideal weights!
        for (uint256 i; i < vaultsWithAmount.length; i++) {
            if (!(vaultsLocal[i].allStablecoinsCloseToPeg)) {
                if (deltaWeights[i] > idealWeights[i]) {
                    return false;
                }
            }

            if (!vaultsWithinEpsilon[i]) {
                // check if deltaWeights[i] is closer to _idealWeights[i] than _currentWeights[i]
                uint256 distanceDeltaToIdeal = deltaWeights[i].absSub(idealWeights[i]);
                uint256 distanceCurrentToIdeal = currentWeights[i].absSub(idealWeights[i]);

                if (distanceDeltaToIdeal >= distanceCurrentToIdeal) {
                    return false;
                }
            }
        }

        return true;
    }

    function vaultFlattener(
        VaultWithAmount[] memory vaultsWithAmount,
        VaultLocal[] memory vaultsLocal
    )
        internal
        view
        returns (
            uint256[] memory amounts,
            uint256[] memory prices,
            uint256[] memory idealWeights,
            uint256[] memory currentWeights
        )
    {
        for (uint256 i; i < vaultsWithAmount.length; i++) {
            amounts[i] = vaultsWithAmount[i].amount;
            prices[i] = vaultsWithAmount[i].vaultInfo.price;
            idealWeights[i] = vaultsLocal[i].idealWeight;
            currentWeights[i] = vaultsWithAmount[i].vaultInfo.currentWeight;
        }

        return (amounts, prices, idealWeights, currentWeights);
    }

    function gyroscopeKeptSpinningMint(
        VaultWithAmount[] memory vaultsWithAmount,
        VaultLocal[] memory vaultsLocal
    ) public view returns (bool) {
        (bool allVaultStablecoinsCloseToPeg, ) = vaultStablecoinStatus(vaultsLocal);
        (bool allVaultsWithinEpsilon, bool[] memory vaultsWithinEpsilon) = checkVaultsWithinEpsilon(
            vaultsLocal
        );
        if (allVaultStablecoinsCloseToPeg) {
            if (allVaultsWithinEpsilon) {
                return true;
            }
        } else {
            (
                uint256[] memory inputAmounts,
                uint256[] memory currentWeights,
                uint256[] memory prices,
                uint256[] memory idealWeights
            ) = vaultFlattener(vaultsWithAmount, vaultsLocal);

            (uint256[] memory deltaWeights, uint256 totalPortfolioValue) = calculateWeightsAndTotal(
                inputAmounts,
                prices
            );

            if (totalPortfolioValue == 0) {
                deltaWeights = idealWeights;
            }

            if (allVaultsWithinEpsilon) {
                if (checkUnhealthyMovesToIdeal(vaultsLocal, deltaWeights, idealWeights)) {
                    return true;
                }
            } else {
                if (
                    safeToMintOutsideEpsilon(
                        vaultsWithAmount,
                        vaultsLocal,
                        deltaWeights,
                        idealWeights,
                        currentWeights,
                        vaultsWithinEpsilon
                    )
                ) {
                    return true;
                }
            }
        }
        return false;
    }

    function gyroscopeKeptSpinningRedeem(
        VaultWithAmount[] memory vaultsWithAmount,
        VaultLocal[] memory vaultsLocal
    ) public view returns (bool) {
        (bool allVaultStablecoinsCloseToPeg, ) = vaultStablecoinStatus(vaultsLocal);
        (bool allVaultsWithinEpsilon, bool[] memory vaultsWithinEpsilon) = checkVaultsWithinEpsilon(
            vaultsLocal
        );

        if (allVaultsWithinEpsilon) {
            return true;
        }

        for (uint256 i = 0; i < vaultsWithAmount.length; i++) {
            if (vaultsWithinEpsilon[i]) {
                continue;
            }

            (
                uint256[] memory inputAmounts,
                uint256[] memory currentWeights,
                uint256[] memory prices,
                uint256[] memory idealWeights
            ) = vaultFlattener(vaultsWithAmount, vaultsLocal);

            (uint256[] memory deltaWeights, ) = calculateWeightsAndTotal(inputAmounts, prices);

            uint256 distanceDeltaToIdeal = deltaWeights[i].absSub(idealWeights[i]);
            uint256 distanceCurrentToIdeal = currentWeights[i].absSub(idealWeights[i]);

            if (distanceDeltaToIdeal >= distanceCurrentToIdeal) {
                return false;
            }
        }

        return true;
    }

    // /// @inheritdoc ISafetyCheck
    // function checkAndPersistMint(VaultWithAmount[] memory vaultsWithAmount)
    //     external
    //     returns (string memory);

    // /// @inheritdoc ISafetyCheck
    // function isMintSafe(VaultWithAmount[] memory vaultsWithAmount)
    //     external
    //     view
    //     returns (string memory);

    // /// @inheritdoc ISafetyCheck
    // function isRedeemSafe(VaultWithAmount[] memory vaultsWithAmount)
    //     external
    //     view
    //     returns (string memory);

    // /// @inheritdoc ISafetyCheck
    // function checkAndPersistRedeem(VaultWithAmount[] memory vaultsWithAmount)
    //     external
    //     returns (string memory);
}
