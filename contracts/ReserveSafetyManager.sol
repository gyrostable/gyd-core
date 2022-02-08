// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./auth/Governable.sol";
import "../libraries/DataTypes.sol";
import "../libraries/FixedPoint.sol";
import "../interfaces/IVaultManager.sol";
import "../interfaces/IAssetRegistry.sol";
import "../interfaces/balancer/IVault.sol";
import "../libraries/Errors.sol";

contract ReserveSafetyManager is Ownable, Governable {
    using FixedPoint for uint256;

    uint256 private maxAllowedVaultDeviation;
    uint256 private stablecoinMaxDeviation;
    address private balancerVaultAddress;
    address private priceOracleAddress;
    address private assetRegistryAddress;

    /// @notice a stablecoin should be equal 1 USD
    uint256 public constant STABLECOIN_IDEAL_PRICE = 1e18;

    // TO-DO: Move this to the IVaultRegistry
    struct VaultMetadata {
        uint256 initialVaultPrice;
        uint256 initialVaultWeight;
    }

    constructor(uint256 _maxAllowedVaultDeviation) {
        maxAllowedVaultDeviation = _maxAllowedVaultDeviation;
    }

    function getVaultMaxDeviation() external view returns (uint256) {
        return maxAllowedVaultDeviation;
    }

    function setVaultMaxDeviation(uint256 _maxAllowedVaultDeviation) external governanceOnly {
        maxAllowedVaultDeviation = _maxAllowedVaultDeviation;
    }

    function _wouldVaultsRemainBalanced(DataTypes.VaultInfo[] memory vaults)
        internal
        view
        returns (bool)
    {
        for (uint256 i = 0; i < vaults.length; i++) {
            bool balanced = vaults[i].idealWeight.absSub(vaults[i].requestedWeight) <=
                maxAllowedVaultDeviation;
            if (!balanced) {
                return false;
            }
        }
        return true;
    }

    function _wouldVaultsBeRebalancing(DataTypes.VaultInfo[] memory vaults)
        internal
        view
        returns (bool)
    {
        for (uint256 i = 0; i < vaults.length; i++) {
            bool rebalancing = vaults[i].idealWeight.absSub(vaults[i].requestedWeight) <
                vaults[i].idealWeight.absSub(vaults[i].currentWeight);
            if (!rebalancing) {
                return false;
            }
        }
        return true;
    }

    function updateVaultsLatestIdealWeights(DataTypes.VaultInfo[] memory vaults)
        internal
        pure
        returns (DataTypes.VaultInfo[] memory)
    {
        uint256[] memory weightedReturns = new uint256[](vaults.length);

        uint256 returnsSum;
        for (uint256 i = 0; i < vaults.length; i++) {
            weightedReturns[i] = (vaults[i].price).divDown(vaults[i].initialPrice).mulDown(
                vaults[i].initialWeight
            );
            returnsSum = returnsSum + weightedReturns[i];
        }

        for (uint256 i = 0; i < vaults.length; i++) {
            vaults[i].idealWeight = weightedReturns[i].divDown(returnsSum);
        }

        return vaults;
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

    function vaultStablecoinStatus(DataTypes.VaultInfo[] memory vaults)
        internal
        view
        returns (bool, DataTypes.VaultInfo[] memory)
    {
        bool allStablecoinsCloseToPeg = true;
        for (uint256 i = 0; i < vaults.length; i++) {
            vaults[i].allStablecoinsNearPeg = areAllPoolStablecoinsCloseToPeg(
                vaults[i].underlyingPoolId
            );
            allStablecoinsCloseToPeg = false;
        }
        return (allStablecoinsCloseToPeg, vaults);
    }

    function _inputWeightsLessThanIdealWeights(DataTypes.VaultInfo[] memory vaults)
        internal
        view
        returns (bool)
    {
        for (uint256 i; i < vaults.length; i++) {
            if (vaults[i].allStablecoinsNearPeg) {
                continue;
            }

            if (vaults[i].requestedWeight > vaults[i].idealWeight) {
                return false;
            }
        }
        return true;
    }

    function safeToMintOutsideEpsilon(DataTypes.VaultInfo[] memory vaults)
        internal
        pure
        returns (bool _anyCheckFail)
    {
        //Check that amount above epsilon is decreasing
        //Check that unhealthy pools have input weight below ideal weight
        //If both true, then mint
        //note: should always be able to mint at the ideal weights!
        _anyCheckFail = false;
        for (uint256 i; i < vaults.length; i++) {
            if (!(vaults[i].allStablecoinsNearPeg)) {
                if (_inputBPTWeights[i] > _idealWeights[i]) {
                    _anyCheckFail = true;
                    break;
                }
            }

            if (!_poolsWithinEpsilon[i]) {
                // check if _hypotheticalWeights[i] is closer to _idealWeights[i] than _currentWeights[i]
                uint256 _distanceHypotheticalToIdeal = absValueSub(
                    _hypotheticalWeights[i],
                    _idealWeights[i]
                );
                uint256 _distanceCurrentToIdeal = absValueSub(_currentWeights[i], _idealWeights[i]);

                if (_distanceHypotheticalToIdeal >= _distanceCurrentToIdeal) {
                    _anyCheckFail = true;
                    break;
                }
            }
        }

        if (!_anyCheckFail) {
            return true;
        }
    }

    //Note assumes that everything is up to date, including that the ideal weights have been recalculated with latest prices
    function gyroscopeKeptSpinning(DataTypes.VaultInfo[] memory vaults) public view returns (bool) {
        (bool allVaultStablecoinsCloseToPeg, ) = vaultStablecoinStatus(vaults);
        if (allVaultStablecoinsCloseToPeg) {
            if (_wouldVaultsRemainBalanced(vaults)) {
                return true;
            }
        } else if (_wouldVaultsRemainBalanced(vaults)) {
            //To-Do: Make sure that if totalportfolio value is zero, the requested weights are the ideal weights.
            if (_inputWeightsLessThanIdealWeights(vaults)) {
                return true;
            }
        } else {
            if (_safeOutsideEpsilon(vaults)) {
                return true;
            }
        }

        return false;
    }

    // function mintChecksPassInternal(
    //     address[] memory _BPTokensIn,
    //     uint256[] memory _amountsIn,
    //     uint256 _minGyroMinted
    // )
    //     internal
    //     view
    //     returns (
    //         uint256 errorCode,
    //         Weights memory weights,
    //         FlowLogger memory flowLogger
    //     )
    // {
    //     require(
    //         _BPTokensIn.length == _amountsIn.length,
    //         "tokensIn and valuesIn should have the same number of elements"
    //     );

    //     //Filter 1: Require that the tokens are supported and in correct order
    //     bool _orderCorrect = checkBPTokenOrder(_BPTokensIn);
    //     require(_orderCorrect, "Input tokens in wrong order or contains invalid tokens");

    //     uint256[] memory _allUnderlyingPrices = getAllTokenPrices();

    //     uint256[] memory _currentBPTPrices = calculateAllPoolPrices(_allUnderlyingPrices);

    //     weights._zeroArray = new uint256[](_BPTokensIn.length);
    //     for (uint256 i = 0; i < _BPTokensIn.length; i++) {
    //         weights._zeroArray[i] = 0;
    //     }

    //     (
    //         weights._idealWeights,
    //         weights._currentWeights,
    //         weights._hypotheticalWeights,
    //         weights._nav,
    //         weights._totalPortfolioValue
    //     ) = calculateAllWeights(_currentBPTPrices, _BPTokensIn, _amountsIn, weights._zeroArray);

    //     bool _safeToMint =
    //         safeToMint(
    //             _BPTokensIn,
    //             weights._hypotheticalWeights,
    //             weights._idealWeights,
    //             _allUnderlyingPrices,
    //             _amountsIn,
    //             _currentBPTPrices,
    //             weights._currentWeights
    //         );

    //     if (!_safeToMint) {
    //         errorCode |= WOULD_UNBALANCE_GYROSCOPE;
    //     }

    //     weights._dollarValue = 0;

    //     for (uint256 i = 0; i < _BPTokensIn.length; i++) {
    //         weights._dollarValue = weights._dollarValue.add(
    //             _amountsIn[i].scaledMul(_currentBPTPrices[i])
    //         );
    //     }

    //     flowLogger = initializeFlowLogger();

    //     weights.gyroAmount = gyroPriceOracle.getAmountToMint(
    //         weights._dollarValue,
    //         flowLogger.inflowHistory,
    //         weights._nav
    //     );

    //     if (weights.gyroAmount < _minGyroMinted) {
    //         errorCode |= TOO_MUCH_SLIPPAGE;
    //     }

    //     return (errorCode, weights, flowLogger);
    // }
}
