// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

/// @notice Defines different configuration keys used in the Gyroscope system
library ConfigKeys {
    // Addresses
    bytes32 internal constant GYD_TOKEN_ADDRESS = "GYD_TOKEN_ADDRESS";
    bytes32 internal constant PAMM_ADDRESS = "PAMM_ADDRESS";
    bytes32 internal constant RESERVE_ADDRESS = "RESERVE_ADDRESS";
    bytes32 internal constant ROOT_PRICE_ORACLE_ADDRESS = "ROOT_PRICE_ORACLE_ADDRESS";
    bytes32 internal constant ROOT_SAFETY_CHECK_ADDRESS = "ROOT_SAFETY_CHECK_ADDRESS";
    bytes32 internal constant VAULT_REGISTRY_ADDRESS = "VAULT_REGISTRY_ADDRESS";
    bytes32 internal constant ASSET_REGISTRY_ADDRESS = "ASSET_REGISTRY_ADDRESS";
    bytes32 internal constant RESERVE_MANAGER_ADDRESS = "RESERVE_MANAGER_ADDRESS";
    bytes32 internal constant FEE_HANDLER_ADDRESS = "FEE_HANDLER_ADDRESS";
    bytes32 internal constant MOTHERBOARD_ADDRESS = "MOTHERBOARD_ADDRESS";
    bytes32 internal constant CAP_AUTHENTICATION_ADDRESS = "CAP_AUTHENTICATION_ADDRESS";
    bytes32 internal constant GYD_RECOVERY_ADDRESS = "GYD_RECOVERY_ADDRESS";
    bytes32 internal constant BALANCER_VAULT_ADDRESS = "BALANCER_VAULT_ADDRESS";
    bytes32 internal constant RATE_MANAGER_ADDRESS = "RATE_MANAGER_ADDRESS";

    bytes32 internal constant STEWARDSHIP_INC_ADDRESS = "STEWARDSHIP_INC_ADDRESS";
    bytes32 internal constant STEWARDSHIP_INC_MIN_CR = "STEWARDSHIP_INC_MIN_CR";
    bytes32 internal constant STEWARDSHIP_INC_DURATION = "STEWARDSHIP_INC_DURATION";
    bytes32 internal constant STEWARDSHIP_INC_MAX_VIOLATIONS = "STEWARDSHIP_INC_MAX_VIOLATIONS";

    bytes32 internal constant GOV_TREASURY_ADDRESS = "GOV_TREASURY_ADDRESS";

    // Uints
    bytes32 internal constant GYD_GLOBAL_SUPPLY_CAP = "GYD_GLOBAL_SUPPLY_CAP";
    bytes32 internal constant GYD_AUTHENTICATED_USER_CAP = "GYD_AUTHENTICATED_USER_CAP";
    bytes32 internal constant GYD_USER_CAP = "GYD_USER_CAP";

    bytes32 internal constant GYD_RECOVERY_TRIGGER_CR = "GYD_RECOVERY_TRIGGER_CR";
    bytes32 internal constant GYD_RECOVERY_TARGET_CR = "GYD_RECOVERY_TARGET_CR";

    bytes32 internal constant SAFETY_BLOCKS_AUTOMATIC = "SAFETY_BLOCKS_AUTOMATIC";
    bytes32 internal constant SAFETY_BLOCKS_GUARDIAN = "SAFETY_BLOCKS_GUARDIAN";

    bytes32 internal constant REDEEM_DISCOUNT_RATIO = "REDEEM_DISCOUNT_RATIO";
    bytes32 internal constant VAULT_DUST_THRESHOLD = "VAULT_DUST_THRESHOLD";
    bytes32 internal constant STABLECOIN_MAX_DEVIATION = "STABLECOIN_MAX_DEVIATION";
}
