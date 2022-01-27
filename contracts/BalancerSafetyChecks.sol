// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../interfaces/balancer/IVault.sol";
import "../interfaces/IBalancerPool.sol";
import "../libraries/DataTypes.sol";
import "../libraries/FixedPoint.sol";

/**
    @title Contract containing the safety checks performed on Balancer pools
//  */
contract BalancerSafetyChecks is Ownable {
    using SafeERC20 for ERC20;
    using FixedPoint for uint256;

    /// @notice a stablecoin should be equal 1 USD
    uint256 public constant STABLECOIN_IDEAL_PRICE = 1e18;

    /// @dev this should be scaled by 10^18, i.e. 1e16 == 1%
    uint256 public stablecoinMaxDeviation = 1e16;

    address private balancerVaultAddress;
    uint256 private maxActivityLag;


    mapping(address => DataTypes.TokenProperties) _tokenProperties;

    constructor(address _balancerVaultAddress, uint256 _maxActivityLag) {
        balancerVaultAddress = _balancerVaultAddress;
        maxActivityLag = _maxActivityLag;
    }

    function isPoolPaused(bytes32 poolId) internal view returns (bool) {
        IVault balVault = IVault(balancerVaultAddress);
        (address poolAddress, ) = balVault.getPool(poolId);
        IBalancerPool pool = IBalancerPool(poolAddress);
        (bool paused, , ) = pool.getPausedState();
        return paused;
    }

    // function arePoolAssetWeightsCloseToDesired(bytes32 poolId) internal view returns (bool) {
    //     IVault balVault = IVault(balancerVaultAddress);
    //     (IERC20[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock) = balVault.getPoolTokens(poolId);
    //     //Finish implementation
        
    //     (address poolAddress, ) = balVault.getPool(poolId);
    //     IBalancerPool pool = IBalancerPool(poolAddress);
    //     uint256[] memory normlizedWeights = pool.getNormalizedWeights(); 

    // }

    function doesPoolHaveLiveness(bytes32 poolId) internal view returns (bool) {
        IVault balVault = IVault(balancerVaultAddress);
        (IERC20[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock) = balVault.getPoolTokens(poolId);
        bool lastChangeRecent = lastChangeBlock.absSub(block.number) <=
            maxActivityLag;        
        return lastChangeRecent;        
    }

    /// @dev stablecoinPrice must be scaled to 10^18
    function isStablecoinHealthy(uint256 stablecoinPrice) internal view returns (bool) {
        return stablecoinPrice.absSub(STABLECOIN_IDEAL_PRICE) <= stablecoinMaxDeviation;
    }

    function arePoolStablecoinsHealthy(uint256[] memory allUnderlyingPrices, bytes32 poolId)
        internal
        view
        returns (bool)
    {
        IVault balVault = IVault(balancerVaultAddress);

        (IERC20[] memory tokens, , ) = balVault.getPoolTokens(poolId);

        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenAddress = address(tokens[i]);
            if (_tokenProperties[tokenAddress].isStablecoin) {
                uint256 stablecoinPrice = allUnderlyingPrices[
                    _tokenProperties[tokenAddress].tokenIndex
                ];

                if (!isStablecoinHealthy(stablecoinPrice)) {
                    return false;
                }
            }
        }

        return true;
    }

    // function areAllPoolsHealthy(
    //     bytes32[] memory poolIds,
    //     uint256[] memory allUnderlyingPrices
    // ) external view returns (bool, bool[] memory) {
    //     bool[] memory poolHealth = new bool[](poolIds.length);
    //     bool allPoolsHealthy = true;

    //     for (uint256 i = 0; i < poolIds.length; i++) {
    //         poolHealth[i] = isPoolOperatingNormally(allUnderlyingPrices, poolIds[i]);
    //         allPoolsHealthy = allPoolsHealthy && poolHealth[i];
    //     }

    //     return (allPoolsHealthy, poolHealth);
    // }
}
