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

    /// @notice Vault with metadata
    struct VaultInfo {
        address vault;
        uint256 price;
        uint256 initialPrice;
        uint256 initialWeight;
        uint256 reserveBalance;
        uint256 idealWeight;
        uint256 currentWeight;
        uint256 requestedWeight;
        bool allStablecoinsNearPeg;
        bool withinEpsilon;
        bool isPaused;
        bytes32 underlyingPoolId;
    }

    struct TokenProperties {
        address oracleAddress;
        string tokenSymbol;
        uint16 tokenIndex;
        bool isStablecoin;
    }

    struct PoolProperties {
        bytes32 poolId;
        address poolAddress;
        uint256 initialPoolWeight;
        uint256 initialPoolPrice;
    }
}
