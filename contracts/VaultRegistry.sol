// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./auth/GovernableUpgradeable.sol";

import "../libraries/ConfigKeys.sol";
import "../libraries/FixedPoint.sol";
import "../libraries/ConfigHelpers.sol";
import "../libraries/EnumerableExtensions.sol";

import "../interfaces/IVaultRegistry.sol";
import "../interfaces/IGyroConfig.sol";

contract VaultRegistry is IVaultRegistry, GovernableUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using ConfigHelpers for IGyroConfig;

    IGyroConfig public immutable gyroConfig;

    EnumerableSet.AddressSet internal vaultAddresses;

    mapping(address => DataTypes.PersistedVaultMetadata) internal vaultsMetadata;

    constructor(IGyroConfig _gyroConfig) {
        gyroConfig = _gyroConfig;
    }

    modifier reserveManagerOnly() {
        require(
            msg.sender == address(gyroConfig.getReserveManager()),
            Errors.CALLER_NOT_RESERVE_MANAGER
        );
        _;
    }

    /// @inheritdoc IVaultRegistry
    function listVaults() external view override returns (address[] memory) {
        return vaultAddresses.values();
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
    function setVaults(DataTypes.VaultConfiguration[] calldata vaults)
        external
        override
        reserveManagerOnly
    {
        _removeAllVaults();

        uint256 totalWeight;

        for (uint256 i; i < vaults.length; i++) {
            address vault = vaults[i].vaultAddress;
            require(gyroConfig.getFeeHandler().isVaultSupported(vault), Errors.VAULT_NOT_FOUND);
            require(vaultAddresses.add(vault), Errors.INVALID_ARGUMENT);
            vaultsMetadata[vault] = vaults[i].metadata;
            totalWeight += vaults[i].metadata.weightAtLastCalibration;
        }

        require(totalWeight == FixedPoint.ONE, Errors.INVALID_ARGUMENT);
        emit VaultsSet(vaults);
    }

    function setInitialPrice(address vault, uint256 initialPrice) external reserveManagerOnly {
        require(vaultAddresses.contains(vault), Errors.VAULT_NOT_FOUND);
        require(vaultsMetadata[vault].priceAtLastCalibration == 0, Errors.INVALID_ARGUMENT);
        vaultsMetadata[vault].priceAtLastCalibration = initialPrice;
    }

    function updatePersistedVaultFlowParams(
        address[] memory vaultsToUpdate,
        uint256[] memory newShortFlowMemory,
        uint256[] memory newShortFlowThreshold
    ) external governanceOnly {
        for (uint256 i = 0; i < vaultsToUpdate.length; i++) {
            require(vaultAddresses.contains(vaultsToUpdate[i]), Errors.VAULT_NOT_FOUND);
            vaultsMetadata[vaultsToUpdate[i]].shortFlowMemory = newShortFlowMemory[i];
            vaultsMetadata[vaultsToUpdate[i]].shortFlowThreshold = newShortFlowThreshold[i];
        }
    }

    function _removeAllVaults() internal {
        address[] memory vaults = vaultAddresses.values();
        for (uint256 i; i < vaults.length; i++) {
            delete vaultsMetadata[vaults[i]];
            vaultAddresses.remove(vaults[i]);
        }
    }
}
