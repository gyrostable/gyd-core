// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./auth/Governable.sol";

import "../libraries/ConfigKeys.sol";
import "../libraries/EnumerableExtensions.sol";

import "../interfaces/IVaultRegistry.sol";
import "../interfaces/oracles/IUSDPriceOracle.sol";
import "../interfaces/IGyroConfig.sol";

contract VaultRegistry is IVaultRegistry, Governable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableExtensions for EnumerableSet.AddressSet;

    IGyroConfig public immutable gyroConfig;

    EnumerableSet.AddressSet internal vaultAddresses;

    mapping(address => DataTypes.PersistedVaultMetadata) internal vaultsMetadata;

    constructor(IGyroConfig _gyroConfig) {
        gyroConfig = _gyroConfig;
    }

    /// @inheritdoc IVaultRegistry
    function listVaults() external view override returns (address[] memory) {
        return vaultAddresses.toArray();
    }

    /// @inheritdoc IVaultRegistry
    function getVaultMetadata(address vault)
        external
        view
        override
        returns (DataTypes.PersistedVaultMetadata memory)
    {
        return vaultsMetadata[vault];
    }

    /// @inheritdoc IVaultRegistry
    function registerVault(
        address vault,
        uint256 initialVaultWeight,
        bytes32 underlyingPoolId
    ) external override governanceOnly {
        require(!vaultAddresses.contains(vault), Errors.VAULT_ALREADY_EXISTS);
        vaultAddresses.add(vault);
        uint256 price = IUSDPriceOracle(gyroConfig.getAddress(ConfigKeys.ROOT_PRICE_ORACLE_ADDRESS))
            .getPriceUSD(vault);
        vaultsMetadata[vault] = DataTypes.PersistedVaultMetadata({
            initialWeight: initialVaultWeight,
            initialPrice: price,
            underlyingPoolId: underlyingPoolId
        });
        emit VaultRegistered(vault);
    }

    /// @inheritdoc IVaultRegistry
    function deregisterVault(address vault) external override governanceOnly {
        require(vaultAddresses.contains(vault), Errors.VAULT_NOT_FOUND);
        vaultAddresses.remove(vault);
        emit VaultDeregistered(vault);
    }
}
