// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../libraries/DataTypes.sol";

interface ISafetyCheck {
    /// @notice Checks whether a mint operation is safe
    /// This is only called when an actual mint is performed
    /// The implementation should store any relevant information for the mint
    /// @return empty string if it is safe, otherwise the reason why it is not safe
    function checkAndPersistMint(DataTypes.Order memory order) external returns (string memory);

    /// @notice Checks whether a mint operation is safe
    /// @return empty string if it is safe, otherwise the reason why it is not safe
    function isMintSafe(DataTypes.Order memory order) external view returns (string memory);

    /// @notice Checks whether a redeem operation is safe
    /// @return empty string if it is safe, otherwise the reason why it is not safe
    function isRedeemSafe(DataTypes.Order memory order) external view returns (string memory);

    /// @notice Checks whether a redeem operation is safe
    /// This is only called when an actual redeem is performed
    /// The implementation should store any relevant information for the redeem
    /// @return empty string if it is safe, otherwise the reason why it is not safe
    function checkAndPersistRedeem(DataTypes.Order memory order) external returns (string memory);
}
