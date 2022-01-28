// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../interfaces/balancer/IVault.sol";
import "../interfaces/IBalancerPool.sol";
import "../libraries/DataTypes.sol";
import "../libraries/FixedPoint.sol";
import "../interfaces/IAssetPricer.sol";

/**
    @title Contract containing the safety checks performed on Balancer pools
//  */
contract BalancerSafetyChecks is Ownable {
    using SafeERC20 for ERC20;
    using FixedPoint for uint256;

    /// @notice a stablecoin should be equal 1 USD
    uint256 public constant STABLECOIN_IDEAL_PRICE = 1e18;

    address private balancerVaultAddress;
    address private assetPricerAddress;
    uint256 private maxActivityLag;
    uint256 private stablecoinMaxDeviation;
    uint256 private poolWeightMaxDeviation;


    mapping(address => DataTypes.TokenProperties) _tokenProperties;

    constructor(address _balancerVaultAddress, uint256 _maxActivityLag, uint256 _stablecoinMaxDeviation, uint256 _poolWeightMaxDeviation) {
        balancerVaultAddress = _balancerVaultAddress;
        maxActivityLag = _maxActivityLag;
        stablecoinMaxDeviation = _stablecoinMaxDeviation; /// @dev this should be scaled by 10^18, i.e. 1e16 == 1%
        poolWeightMaxDeviation = _poolWeightMaxDeviation; /// @dev this should be scaled by 10^18, i.e. 1e16 == 1%
    }

    function isPoolPaused(bytes32 poolId) internal view returns (bool) {
        IVault balVault = IVault(balancerVaultAddress);
        (address poolAddress, ) = balVault.getPool(poolId);
        IBalancerPool balancerPool = IBalancerPool(poolAddress);
        (bool paused, , ) = balancerPool.getPausedState();
        return paused;
    }

    function arePoolAssetWeightsCloseToStated(bytes32 poolId) internal view returns (bool) {
        IVault balVault = IVault(balancerVaultAddress);
        IAssetPricer assetPricer = IAssetPricer(assetPricerAddress);
        (address poolAddress, ) = balVault.getPool(poolId);
        IBalancerPool balancerPool = IBalancerPool(poolAddress);


        (IERC20[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock) = balVault.getPoolTokens(poolId);
        require (tokens.length == balances.length);

        DataTypes.MonetaryAmount[] memory MonetaryAmounts = new DataTypes.MonetaryAmount[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            MonetaryAmounts[i] = DataTypes.MonetaryAmount({tokenAddress: address(tokens[i]), amount: balances[i]});
        }

        uint256[] memory weights = new uint256[](MonetaryAmounts.length);
        uint256[] memory assetPrices = new uint256[](MonetaryAmounts.length);

        uint256 totalPoolUSDValue = 0;
        for (uint256 i = 0; i < MonetaryAmounts.length; i ++) {
            uint256 usdValue = assetPricer.getUSDValue(MonetaryAmounts[i]);
            assetPrices[i] = usdValue;
            totalPoolUSDValue = totalPoolUSDValue + usdValue;
        }
        require (totalPoolUSDValue > 0, Errors.POOL_HAS_ZERO_USD_VALUE);
    

        for (uint256 i=0; i < MonetaryAmounts.length; i++) {
            weights[i] = MonetaryAmounts[i].amount.mulDown(assetPrices[i]).divDown(totalPoolUSDValue);
        }
        
        uint256[] memory normalizedWeights = balancerPool.getNormalizedWeights();

        for (uint256 i = 0; i < weights.length; i++) {
            if (weights[i].absSub(normalizedWeights[i]) > poolWeightMaxDeviation) {
                return false;
            }
        }

        return true;

    }

    function doesPoolHaveLiveness(bytes32 poolId) internal view returns (bool) {
        IVault balVault = IVault(balancerVaultAddress);
        (IERC20[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock) = balVault.getPoolTokens(poolId);
        bool lastChangeRecent = lastChangeBlock.absSub(block.number) <=
            maxActivityLag;        
        return lastChangeRecent;        
    }

    /// @dev stablecoinPrice must be scaled to 10^18
    function isStablecoinCloseToPeg(uint256 stablecoinPrice) internal view returns (bool) {
        return stablecoinPrice.absSub(STABLECOIN_IDEAL_PRICE) <= stablecoinMaxDeviation;
    }

    // function areAllPoolStablecoinsCloseToPeg(bytes32 poolId)
    //     internal
    //     view
    //     returns (bool)
    // {
    //     IVault balVault = IVault(balancerVaultAddress);

    //     (IERC20[] memory tokens, , ) = balVault.getPoolTokens(poolId);

    //     for (uint256 i = 0; i < tokens.length; i++) {

    //         // if (token is stablecoin) {
    //         //     check that stablecoincoin is close to peg. If not, return false. 
    //         // }
    //         if (_tokenProperties[tokenAddress].isStablecoin) {
    //             uint256 stablecoinPrice = allUnderlyingPrices[
    //                 _tokenProperties[tokenAddress].tokenIndex
    //             ];

    //             if (!isStablecoinCloseToPeg(stablecoinPrice)) {
    //                 return false;
    //             }
    //         }
    //     }

    //     return true;
    // }

    function arePoolsSafe(bytes32[] memory poolIds) external view returns (bool) {
        for (uint256 i = 0; i < poolIds.length; i++) {
            bool poolLiveness = doesPoolHaveLiveness(poolIds[i]);
            require (poolLiveness, Errors.POOL_DOES_NOT_HAVE_LIVENESS);

            bool poolPaused = isPoolPaused(poolIds[i]);
            require (!poolPaused, Errors.POOL_IS_PAUSED);

            bool assetsNearWeights = arePoolAssetWeightsCloseToStated(poolIds[i]);
            require (assetsNearWeights, Errors.ASSETS_NOT_CLOSE_TO_POOL_WEIGHTS);

            // bool stablecoinsInPoolCloseToPeg = areAllPoolStablecoinsCloseToPeg(poolIds[i]);
            // require (stablecoinsInPoolCloseToPeg, Errors.STABLECOIN_IN_POOL_NOT_CLOSE_TO_PEG);

        }

        return true;
    }
}
