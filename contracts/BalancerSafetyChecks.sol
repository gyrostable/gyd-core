// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../interfaces/balancer/IVault.sol";
import "../libraries/DataTypes.sol";

/**
    @title Contract containing the safety checks performed on Balancer pools
//  */
contract BalancerSafetyChecks is Ownable {
    using SafeERC20 for ERC20;

    address private balancerVaultAddress;

    mapping(address => bool) isStablecoin;
    mapping(address => DataTypes.TokenProperties) _tokenAddressToProperties;
    mapping(address => DataTypes.PoolProperties) _poolIdtoProperties;

    constructor(address _balancerVaultAddress) {
        balancerVaultAddress = _balancerVaultAddress;
    }

    function checkStablecoinHealth(
        uint256 stablecoinPrice,
        address stablecoinAddress
    ) internal view returns (bool) {
        // TODO: revisit
        //Price
        bool _stablecoinHealthy = true;

        uint256 decimals = ERC20(stablecoinAddress).decimals();

        uint256 maxDeviation = 5 * 10**(decimals - 2);
        uint256 idealPrice = 10**decimals;

        if (stablecoinPrice >= idealPrice + maxDeviation) {
            _stablecoinHealthy = false;
        } else if (stablecoinPrice <= idealPrice - maxDeviation) {
            _stablecoinHealthy = false;
        }

        //Volume (to do)

        return _stablecoinHealthy;
    }

    function poolOperatingNormally(
        uint256[] memory allUnderlyingPrices,
        bytes32 poolId
    ) internal view returns (bool) {
        bool operatingNormally = true;

        IVault balVault = IVault(balancerVaultAddress);

        (IERC20[] memory tokens, uint256[] memory balances, ) = balVault
            .getPoolTokens(poolId);

        //Need to make sure that correspondence between all underlying prices and tokens is maintained

        // Go through the underlying tokens within the pool
        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenAddress = address(tokens[i]);
            if (isStablecoin[tokenAddress]) {
                uint256 stablecoinPrice = allUnderlyingPrices[
                    _tokenAddressToProperties[tokenAddress].tokenIndex
                ];

                if (!checkStablecoinHealth(stablecoinPrice, tokenAddress)) {
                    operatingNormally = false;
                    break;
                }
            }
        }

        return operatingNormally;
    }

    function checkAllPoolsOperatingNormally(
        bytes32[] memory poolIds,
        uint256[] memory allUnderlyingPrices
    ) external view returns (bool, bool[] memory) {
        bool[] memory PoolsOperatingNormally = new bool[](poolIds.length);
        bool allPoolsOperatingNormally = true;

        for (uint256 i = 0; i < poolIds.length; i++) {
            PoolsOperatingNormally[i] = poolOperatingNormally(
                allUnderlyingPrices,
                poolIds[i]
            );
            allPoolsOperatingNormally =
                allPoolsOperatingNormally &&
                PoolsOperatingNormally[i];
        }

        return (allPoolsOperatingNormally, PoolsOperatingNormally);
    }
}
