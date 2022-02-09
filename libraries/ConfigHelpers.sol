// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./ConfigKeys.sol";

import "../interfaces/oracles/IUSDPriceOracle.sol";
import "../interfaces/ISafetyCheck.sol";
import "../interfaces/IGyroConfig.sol";
import "../interfaces/IVaultRegistry.sol";
import "../interfaces/IVaultManager.sol";

/// @notice Defines helpers to allow easy access to common parts of the configuration
library ConfigHelpers {
    function getRootPriceOracle(IGyroConfig gyroConfig) internal view returns (IUSDPriceOracle) {
        return IUSDPriceOracle(gyroConfig.getAddress(ConfigKeys.ROOT_PRICE_ORACLE_ADDRESS));
    }

    function getRootSafetyCheck(IGyroConfig gyroConfig) internal view returns (ISafetyCheck) {
        return ISafetyCheck(gyroConfig.getAddress(ConfigKeys.ROOT_SAFETY_CHECK_ADDRESS));
    }

    function getVaultRegistry(IGyroConfig gyroConfig) internal view returns (IVaultRegistry) {
        return IVaultRegistry(gyroConfig.getAddress(ConfigKeys.VAULT_REGISTRY_ADDRESS));
    }

    function getVaultManager(IGyroConfig gyroConfig) internal view returns (IVaultManager) {
        return IVaultManager(gyroConfig.getAddress(ConfigKeys.VAULT_MANAGER_ADDRESS));
    }
}
