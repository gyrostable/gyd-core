// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../interfaces/IVaultRegistry.sol";
import "./auth/Governable.sol";

contract VaultRegistry is IVaultRegistry, Governable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet vaultAddresses;

    /// @inheritdoc IVaultRegistry
    function listVaults() external view override returns (address[] memory) {
        uint256 length = vaultAddresses.length();
        address[] memory addresses = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            addresses[i] = vaultAddresses.at(i);
        }
        return addresses;
    }

    /// @inheritdoc IVaultRegistry
    function registerVault(address vault) external override governanceOnly {
        require(!vaultAddresses.contains(vault), Errors.VAULT_ALREADY_EXISTS);
        vaultAddresses.add(vault);
        emit VaultRegistered(vault);
    }

    /// @inheritdoc IVaultRegistry
    function deregisterVault(address vault) external override governanceOnly {
        require(vaultAddresses.contains(vault), Errors.VAULT_NOT_FOUND);
        vaultAddresses.remove(vault);
        emit VaultDeregistered(vault);
    }
}
