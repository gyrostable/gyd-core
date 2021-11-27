// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "OpenZeppelin/openzeppelin-contracts@4.3.2/contracts/access/Ownable.sol";
import "OpenZeppelin/openzeppelin-contracts@4.3.2/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.3.2/contracts/token/ERC20/ERC20.sol";

/**
    @title Contract containing the safety checks performed on Balancer pools
//  */
contract BalancerSafetyChecks is Ownable {
    using SafeERC20 for ERC20;

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

    function poolHealthHelper(
        uint256[] memory _allUnderlyingPrices,
        uint256 _poolIndex
    ) internal view returns (bool) {
        bool _poolHealthy = true;

        // BPool _bPool = BPool(poolProperties[_poolIndex].poolAddress);
        // address[] memory _bPoolUnderlyingTokens = _bPool.getFinalTokens();

        // //Go through the underlying tokens within the pool
        // for (uint256 j = 0; j < _bPoolUnderlyingTokens.length; j++) {
        //     if (_checkIsStablecoin[_bPoolUnderlyingTokens[j]]) {
        //         uint256 _stablecoinPrice = _allUnderlyingPrices[
        //             _tokenAddressToProperties[_bPoolUnderlyingTokens[j]].tokenIndex
        //         ];

        //         if (!checkStablecoinHealth(_stablecoinPrice, _bPoolUnderlyingTokens[j])) {
        //             _poolHealthy = false;
        //             break;
        //         }
        //     }
        // }

        return _poolHealthy;
    }
}
