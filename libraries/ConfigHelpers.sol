// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./ConfigKeys.sol";

import "../interfaces/oracles/IBatchVaultPriceOracle.sol";
import "../interfaces/IMotherboard.sol";
import "../interfaces/ISafetyCheck.sol";
import "../interfaces/IGyroConfig.sol";
import "../interfaces/IVaultRegistry.sol";
import "../interfaces/IAssetRegistry.sol";
import "../interfaces/IReserveManager.sol";
import "../interfaces/IFeeBank.sol";
import "../interfaces/IReserve.sol";
import "../interfaces/IGYDToken.sol";
import "../interfaces/IFeeHandler.sol";
import "../interfaces/ICapAuthentication.sol";

/// @notice Defines helpers to allow easy access to common parts of the configuration
library ConfigHelpers {
    function getRootPriceOracle(IGyroConfig gyroConfig)
        internal
        view
        returns (IBatchVaultPriceOracle)
    {
        return IBatchVaultPriceOracle(gyroConfig.getAddress(ConfigKeys.ROOT_PRICE_ORACLE_ADDRESS));
    }

    function getRootSafetyCheck(IGyroConfig gyroConfig) internal view returns (ISafetyCheck) {
        return ISafetyCheck(gyroConfig.getAddress(ConfigKeys.ROOT_SAFETY_CHECK_ADDRESS));
    }

    function getVaultRegistry(IGyroConfig gyroConfig) internal view returns (IVaultRegistry) {
        return IVaultRegistry(gyroConfig.getAddress(ConfigKeys.VAULT_REGISTRY_ADDRESS));
    }

    function getAssetRegistry(IGyroConfig gyroConfig) internal view returns (IAssetRegistry) {
        return IAssetRegistry(gyroConfig.getAddress(ConfigKeys.ASSET_REGISTRY_ADDRESS));
    }

    function getReserveManager(IGyroConfig gyroConfig) internal view returns (IReserveManager) {
        return IReserveManager(gyroConfig.getAddress(ConfigKeys.RESERVE_MANAGER_ADDRESS));
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

    function getFeeHandler(IGyroConfig gyroConfig) internal view returns (IFeeHandler) {
        return IFeeHandler(gyroConfig.getAddress(ConfigKeys.FEE_HANDLER_ADDRESS));
    }

    function getMotherboard(IGyroConfig gyroConfig) internal view returns (IMotherboard) {
        return IMotherboard(gyroConfig.getAddress(ConfigKeys.MOTHERBOARD_ADDRESS));
    }

    function getGlobalSupplyCap(IGyroConfig gyroConfig) internal view returns (uint256) {
        return gyroConfig.getUint(ConfigKeys.GYD_GLOBAL_SUPPLY_CAP, type(uint256).max);
    }

    function getPerUserSupplyCap(IGyroConfig gyroConfig, bool authenticated)
        internal
        view
        returns (uint256)
    {
        if (authenticated) {
            return gyroConfig.getUint(ConfigKeys.GYD_AUTHENTICATED_USER_CAP, type(uint256).max);
        }
        return gyroConfig.getUint(ConfigKeys.GYD_USER_CAP, type(uint256).max);
    }

    function isAuthenticated(IGyroConfig gyroConfig, address user) internal view returns (bool) {
        if (!gyroConfig.hasKey(ConfigKeys.CAP_AUTHENTICATION_ADDRESS)) return false;
        return
            ICapAuthentication(gyroConfig.getAddress(ConfigKeys.CAP_AUTHENTICATION_ADDRESS))
                .isAuthenticated(user);
    }
}
