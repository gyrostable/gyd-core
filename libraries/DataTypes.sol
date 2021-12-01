// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

/// @notice Contains the data structures to express token routing
library DataTypes {
    /// @notice Contains a token and the amount associated with it
    struct MonetaryAmount {
        address tokenAddress;
        uint256 amount;
    }

    /// @notice A route from/to a token to a vault
    /// This is used to determine in which vault the token should be deposited
    /// or from which vault it should be withdrawn
    struct TokenToVaultMapping {
        address inputToken;
        address vault;
    }

    struct TokenProperties {
        address oracleAddress;
        string tokenSymbol;
        uint16 tokenIndex;
    }

    struct PoolProperties {
        bytes32 poolId;
        address poolAddress;
        uint256 initialPoolWeight;
        uint256 initialPoolPrice;
    }

    struct Reserve {
        address[] vaultAddresses;
        uint256[] idealVaultWeights;
        uint256[] currentVaultWeights;
        uint256[] inputVaultWeights;
        uint256[] hypotheticalVaultWeights;
        bool[] vaultsWithinEpsilon;
        bool allVaultsWithinEpsilon;
        bool[] vaultHealth;
    }
}
