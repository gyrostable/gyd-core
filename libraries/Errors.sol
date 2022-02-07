// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

/// @notice Defines different errors emitted by Gyroscope contracts
library Errors {
    string public constant TOKEN_AND_AMOUNTS_LENGTH_DIFFER = "1";
    string public constant TOO_MUCH_SLIPPAGE = "2";
    string public constant EXCHANGER_NOT_FOUND = "3";
    string public constant POOL_IDS_NOT_FOUND = "4";
    string public constant WOULD_UNBALANCE_GYROSCOPE = "5";
    string public constant VAULT_ALREADY_EXISTS = "6";
    string public constant VAULT_NOT_FOUND = "7";

    string public constant X_OUT_OF_BOUNDS = "20";
    string public constant Y_OUT_OF_BOUNDS = "21";
    string public constant PRODUCT_OUT_OF_BOUNDS = "22";
    string public constant INVALID_EXPONENT = "23";
    string public constant OUT_OF_BOUNDS = "24";
    string public constant ZERO_DIVISION = "25";
    string public constant ADD_OVERFLOW = "26";
    string public constant SUB_OVERFLOW = "27";
    string public constant MUL_OVERFLOW = "28";
    string public constant DIV_INTERNAL = "29";

    string public constant NOT_AUTHORIZED = "30";
    string public constant INVALID_ARGUMENT = "31";
    string public constant KEY_NOT_FOUND = "32";
    string public constant KEY_FROZEN = "33";

    // Oracle related errors
    string public constant ASSET_NOT_SUPPORTED = "40";
    string public constant STALE_PRICE = "41";
    string public constant NEGATIVE_PRICE = "42";
    string public constant INVALID_MESSAGE = "43";

    //Balancer safety check related errors
    string public constant POOL_HAS_ZERO_USD_VALUE = "51";
    string public constant POOL_DOES_NOT_HAVE_LIVENESS = "52";
    string public constant POOL_IS_PAUSED = "53";
    string public constant ASSETS_NOT_CLOSE_TO_POOL_WEIGHTS = "54";
    string public constant STABLECOIN_IN_POOL_NOT_CLOSE_TO_PEG = "55";
    string public constant DIFFERENT_NUMBER_OF_TOKENS_TO_BALANCES = "56";
    string public constant POOL_DOES_NOT_HAVE_NORMALIZED_WEIGHTS_SET = "57";
    string public constant NO_POOL_ID_REGISTERED = "58";

    //Vault safety check related errors
}
