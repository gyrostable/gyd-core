// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./ConfigKeys.sol";

import "../interfaces/oracles/IUSDPriceOracle.sol";
import "../interfaces/ISafetyCheck.sol";
import "../interfaces/IGyroConfig.sol";
import "../interfaces/IVaultRegistry.sol";
import "../interfaces/IVaultManager.sol";
import "../interfaces/IFeeBank.sol";
import "../interfaces/IReserve.sol";
import "../interfaces/ILPTokenExchangerRegistry.sol";
import "../interfaces/IGYDToken.sol";
import "../interfaces/IFeeHandler.sol";

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

    function getFeeBank(IGyroConfig gyroConfig) internal view returns (IFeeBank) {
        return IFeeBank(gyroConfig.getAddress(ConfigKeys.FEE_BANK_ADDRESS));
    }

    function getReserve(IGyroConfig gyroConfig) internal view returns (IReserve) {
        return IReserve(gyroConfig.getAddress(ConfigKeys.RESERVE_ADDRESS));
    }

    function getGYDToken(IGyroConfig gyroConfig) internal view returns (IGYDToken) {
        return IGYDToken(gyroConfig.getAddress(ConfigKeys.GYD_TOKEN_ADDRESS));
    }

    function getExchangerRegistry(IGyroConfig gyroConfig)
        internal
        view
        returns (ILPTokenExchangerRegistry)
    {
        return
            ILPTokenExchangerRegistry(gyroConfig.getAddress(ConfigKeys.EXCHANGER_REGISTRY_ADDRESS));
    }

    function getFeeHandler(IGyroConfig gyroConfig) internal view returns (IFeeHandler) {
        return IFeeHandler(gyroConfig.getAddress(ConfigKeys.FEE_HANDLER_ADDRESS));
    }
}
