// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface IVaultPriceOracle {
    /// @notice Returns the USD value of the vault token for the given vault
    function getVaultTokenPrice(address vaultAddress) external view returns (uint256);

    /// @notice Same as getVaultTokenPrice but supports multiple vaults at once
    function getVaultTokenPrices(address[] calldata vaultAddresses)
        external
        view
        returns (uint256[] memory);
}
