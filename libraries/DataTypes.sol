// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

/// @notice Contains the data structures to express token routing
library DataTypes {
    /// @notice Contains a token and the amount associated with it
    struct TokenAmount {
        address token;
        uint256 amount;
    }

    /// @notice A route from/to a token to a vault
    /// This is used to determine in which vault the token should be deposited
    /// or from which vault it should be withdrawn
    struct Route {
        TokenAmount tokenAmount;
        address vaultAddress;
    }
}
