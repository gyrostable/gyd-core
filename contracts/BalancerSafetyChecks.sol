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

    mapping(address => bool) _isStablecoin;
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

    function poolHealth(uint256[] memory _allUnderlyingPrices, bytes32 _poolId)
        internal
        view
        returns (bool)
    {
        bool _poolHealthy = true;

        IVault balVault = IVault(balancerVaultAddress);

        (
            IERC20[] memory tokens,
            uint256[] memory balances,
            uint256 lastChangeBlock
        ) = balVault.getPoolTokens(_poolId);

        //Need to make sure that correspondence between all underlying prices and tokens is maintained

        // Go through the underlying tokens within the pool
        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenAddress = address(tokens[i]);
            if (_isStablecoin[tokenAddress]) {
                uint256 _stablecoinPrice = _allUnderlyingPrices[
                    _tokenAddressToProperties[tokenAddress].tokenIndex
                ];

                if (!checkStablecoinHealth(_stablecoinPrice, tokenAddress)) {
                    _poolHealthy = false;
                    break;
                }
            }
        }

        return _poolHealthy;
    }

    function checkAllPoolsHealthy(
        bytes32[] memory _poolIds,
        uint256[] memory _allUnderlyingPrices
    ) internal view returns (bool, bool[] memory) {
        bool[] memory _inputPoolHealth = new bool[](_poolIds.length);
        bool _allPoolsHealthy = true;

        for (uint256 i = 0; i < _poolIds.length; i++) {
            _inputPoolHealth[i] = poolHealth(_allUnderlyingPrices, _poolIds[i]);
            _allPoolsHealthy = _allPoolsHealthy && _inputPoolHealth[i];
        }

        return (_allPoolsHealthy, _inputPoolHealth);
    }
}
