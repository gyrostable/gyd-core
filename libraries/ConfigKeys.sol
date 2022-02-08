// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

/// @notice Defines different configuration keys used in the Gyroscope system
library ConfigKeys {
    // Addresses
    bytes32 internal constant GYD_TOKEN_ADDRESS = "GYD_TOKEN_ADDRESS";
    bytes32 internal constant EXCHANGER_REGISTRY_ADDRESS = "EXCHANGER_REGISTRY_ADDRESS";
    bytes32 internal constant PAMM_ADDRESS = "PAMM_ADDRESS";
    bytes32 internal constant FEE_BANK_ADDRESS = "FEE_BANK_ADDRESS";
    bytes32 internal constant RESERVE_ADDRESS = "RESERVE_ADDRESS";
    bytes32 internal constant ASSET_PRICER_ADDRESS = "ASSET_PRICER_ADDRESS";
    bytes32 internal constant ROOT_PRICE_ORACLE_ADDRESS = "ROOT_PRICE_ORACLE_ADDRESS";

    // Fees
    bytes32 public constant MINT_FEE = "MINT_FEE";
}
