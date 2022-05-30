// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../../interfaces/IBalancerPoolRegistry.sol";
import "./../auth/Governable.sol";
import "../../libraries/Errors.sol";

contract BalancerPoolRegistry is IBalancerPoolRegistry, Governable {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    mapping(address => EnumerableSet.Bytes32Set) internal poolIdRegistry;

    event PoolIDRegistered(address underlyingTokenAddress, bytes32 poolId);
    event PoolIDDeregistered(address underlyingTokenAddress, bytes32 poolId);

    /// @inheritdoc IBalancerPoolRegistry
    /// @notice this returns an array of poolIds for a given token since an underlying
    /// may be supported by multiple Balancer pools
    function getPoolIds(address underlyingTokenAddress)
        external
        view
        override
        returns (bytes32[] memory poolIds)
    {
        poolIds = poolIdRegistry[underlyingTokenAddress].values();
        require(poolIds.length != 0, Errors.POOL_IDS_NOT_FOUND);
        return poolIds;
    }

    /// @inheritdoc IBalancerPoolRegistry
    function registerPoolId(address underlyingTokenAddress, bytes32 poolId)
        external
        override
        governanceOnly
    {
        EnumerableSet.Bytes32Set storage poolIdsForToken = poolIdRegistry[underlyingTokenAddress];
        if (poolIdsForToken.add(poolId)) {
            emit PoolIDRegistered(underlyingTokenAddress, poolId);
        }
    }

    /// @inheritdoc IBalancerPoolRegistry
    function deregisterPoolId(address underlyingTokenAddress, bytes32 poolId)
        external
        override
        governanceOnly
    {
        EnumerableSet.Bytes32Set storage poolIdsForToken = poolIdRegistry[underlyingTokenAddress];
        if (poolIdsForToken.remove(poolId)) {
            emit PoolIDDeregistered(underlyingTokenAddress, poolId);
        }
    }
}
