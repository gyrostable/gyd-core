// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../../libraries/DataTypes.sol";

import "../IGyroVault.sol";

interface IBatchVaultPriceOracle {
    /// @notice Fetches the price of the vault token as well as the underlying tokens
    /// @return the same vaults info with the price data populated
    function fetchPricesUSD(DataTypes.VaultInfo[] memory vaultsInfo)
        external
        view
        returns (DataTypes.VaultInfo[] memory);
}
