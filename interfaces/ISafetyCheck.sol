// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../libraries/DataTypes.sol";

interface ISafetyCheck {
    struct VaultWithAmount {
        DataTypes.VaultInfo vaultInfo;
        uint256 amount;
    }

    struct Order {
        VaultWithAmount[] vaultsWithAmount;
        bool mint;
    }

    /// @notice Checks whether a mint operation is safe
    /// This is only called when an actual mint is performed
    /// The implementation should store any relevant information for the mint
    /// @return empty string if it is safe, otherwise the reason why it is not safe
    function checkAndPersistMint(Order memory order) external returns (string memory);

    /// @notice Checks whether a mint operation is safe
    /// @return empty string if it is safe, otherwise the reason why it is not safe
    function isMintSafe(Order memory order) external view returns (string memory);

    /// @notice Checks whether a redeem operation is safe
    /// @return empty string if it is safe, otherwise the reason why it is not safe
    function isRedeemSafe(Order memory order) external view returns (string memory);

    /// @notice Checks whether a redeem operation is safe
    /// This is only called when an actual redeem is performed
    /// The implementation should store any relevant information for the redeem
    /// @return empty string if it is safe, otherwise the reason why it is not safe
    function checkAndPersistRedeem(Order memory order) external returns (string memory);
}
