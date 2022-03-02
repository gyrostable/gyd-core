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

    /// @notice Asset used to mint
    struct MintAsset {
        address inputToken;
        uint256 inputAmount;
        address destinationVault;
    }

    /// @notice Asset to redeem
    struct RedeemAsset {
        address outputToken;
        uint256 minOutputAmount;
        uint256 valueRatio;
        address originVault;
    }

    /// @notice Persisted metadata about the vault
    struct PersistedVaultMetadata {
        uint256 initialPrice;
        uint256 initialWeight;
    }

    /// @notice Vault with metadata
    struct VaultInfo {
        address vault;
        uint256 price;
        PersistedVaultMetadata persistedMetadata;
        uint256 reserveBalance;
        uint256 currentWeight;
        uint256 idealWeight;
    }

    struct VaultMetadata {
        address vault;
        uint256 idealWeight;
        uint256 currentWeight;
        uint256 resultingWeight;
        uint256 price;
        bool allStablecoinsOnPeg;
        bool allTokenPricesLargeEnough;
        bool vaultWithinEpsilon;
    }

    struct Metadata {
        VaultMetadata[] vaultMetadata;
        bool allVaultsWithinEpsilon;
        bool allStablecoinsAllVaultsOnPeg;
        bool allVaultsUsingLargeEnoughPrices;
        bool mint;
    }

    struct VaultWithAmount {
        DataTypes.VaultInfo vaultInfo;
        uint256 amount;
    }

    struct Order {
        VaultWithAmount[] vaultsWithAmount;
        bool mint;
    }

    struct VaultWithAmount {
        VaultInfo vaultInfo;
        uint256 amount;
    }

    /// @notice Represents a mint or redeem order
    struct Order {
        VaultWithAmount[] vaultsWithAmount;
        bool mint;
    }
}
