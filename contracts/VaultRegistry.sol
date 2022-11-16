// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./auth/Governable.sol";

import "../libraries/ConfigKeys.sol";
import "../libraries/ConfigHelpers.sol";
import "../libraries/EnumerableExtensions.sol";

import "../interfaces/IVaultRegistry.sol";
import "../interfaces/IGyroConfig.sol";

contract VaultRegistry is IVaultRegistry, Governable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableExtensions for EnumerableSet.AddressSet;
    using ConfigHelpers for IGyroConfig;

    IGyroConfig public immutable gyroConfig;
    address public reserveManagerAddress;

    EnumerableSet.AddressSet internal vaultAddresses;

    mapping(address => DataTypes.PersistedVaultMetadata) internal vaultsMetadata;

    /// @notice Emmited when the ReserveManager is changed
    event ReserveManagerAddressChanged(
        address oldReserveManagerAddress,
        address newReserveManagerAddress
    );

    constructor(IGyroConfig _gyroConfig) {
        gyroConfig = _gyroConfig;
    }

    function setReserveManagerAddress(address _address) external governanceOnly {
        address oldReserveManagerAddress = reserveManagerAddress;
        reserveManagerAddress = _address;
        emit ReserveManagerAddressChanged(oldReserveManagerAddress, _address);
    }

    modifier reserveManagerOnly() {
        require(msg.sender == reserveManagerAddress, Errors.CALLER_NOT_RESERVE_MANAGER);
        _;
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
    function registerVault(address vault, DataTypes.PersistedVaultMetadata memory persistedMetadata)
        external
        override
        reserveManagerOnly
    {
        require(!vaultAddresses.contains(vault), Errors.VAULT_ALREADY_EXISTS);
        require(gyroConfig.getFeeHandler().isVaultSupported(vault), Errors.VAULT_NOT_FOUND);
        vaultAddresses.add(vault);
        vaultsMetadata[vault] = persistedMetadata;
        emit VaultRegistered(vault);
    }

    function setInitialPrice(address vault, uint256 initialPrice) external reserveManagerOnly {
        require(vaultAddresses.contains(vault), Errors.VAULT_NOT_FOUND);
        require(vaultsMetadata[vault].initialPrice == 0, Errors.INVALID_ARGUMENT);
        vaultsMetadata[vault].initialPrice = initialPrice;
    }

    function updatePersistedVaultFlowParams(
        address[] memory vaultsToUpdate,
        uint256[] memory newShortFlowMemory,
        uint256[] memory newShortFlowThreshold
    ) external governanceOnly {
        for (uint256 i = 0; i < vaultsToUpdate.length; i++) {
            require(vaultAddresses.contains(vaultsToUpdate[i]), Errors.VAULT_NOT_FOUND);
            vaultsMetadata[vaultsToUpdate[i]].shortFlowMemory = newShortFlowMemory[i];
            vaultsMetadata[vaultsToUpdate[i]].shortFlowMemory = newShortFlowThreshold[i];
        }
    }

    /// @inheritdoc IVaultRegistry
    function deregisterVault(address vault) external override governanceOnly {
        require(vaultAddresses.contains(vault), Errors.VAULT_NOT_FOUND);
        vaultAddresses.remove(vault);
        delete vaultsMetadata[vault];
        emit VaultDeregistered(vault);
    }
}
