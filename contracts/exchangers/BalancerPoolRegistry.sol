// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../../interfaces/IBalancerPoolRegistry.sol";
import "./../auth/Governable.sol";
import "../../libraries/Errors.sol";

contract BalancerPoolRegistry is IBalancerPoolRegistry, Governable {
    mapping(address => bytes32[]) internal poolIdRegistry;

    event PoolIDRegistered(address underlyingTokenAddress, bytes32 poolId);

    /// @inheritdoc IBalancerPoolRegistry
    /// @notice this returns an array of poolIds for a given token since an underlying
    /// may be supported by multiple Balancer pools
    function getPoolIds(address underlyingTokenAddress)
        external
        view
        override
        returns (bytes32[] memory poolIds)
    {
        poolIds = poolIdRegistry[underlyingTokenAddress];
        require(poolIds.length != 0, Errors.POOL_IDS_NOT_FOUND);
        return poolIds;
    }

    /// @inheritdoc IBalancerPoolRegistry
    function registerPoolId(address underlyingTokenAddress, bytes32 poolId)
        external
        override
        governanceOnly
    {
        bytes32[] storage poolIdsforToken = poolIdRegistry[underlyingTokenAddress];
        poolIdsforToken.push(poolId);
        poolIdRegistry[underlyingTokenAddress] = poolIdsforToken;
        emit PoolIDRegistered(underlyingTokenAddress, poolId);
    }

    /// @inheritdoc IBalancerPoolRegistry
    function deregisterPoolId(address underlyingTokenAddress, bytes32 poolId)
        external
        override
        governanceOnly
    {
        for (uint256 i = 0; i < poolIdRegistry[underlyingTokenAddress].length; i++) {
            bytes32 _id = poolIdRegistry[underlyingTokenAddress][i];
            if (_id == poolId) {
                poolIdRegistry[underlyingTokenAddress][i] = poolIdRegistry[underlyingTokenAddress][
                    poolIdRegistry[underlyingTokenAddress].length - 1
                ];
                poolIdRegistry[underlyingTokenAddress].pop();
                break;
            }
        }
    }
}
