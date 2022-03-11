// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../interfaces/IVaultWeightManager.sol";
import "../interfaces/oracles/IUSDPriceOracle.sol";
import "../libraries/DataTypes.sol";

interface IVaultManager {
    event NewVaultWeightManager(address indexed oldManager, address indexed newManager);
    event NewPriceOracle(address indexed oldOracle, address indexed newOracle);

    /// @notice Returns a list of vaults without including any metadata
    function listVaults() external view returns (DataTypes.VaultInfo[] memory);

    /// @notice Returns a list of vaults with requested metadata
    function listVaults(
        bool includeMetadata,
        bool includePrice,
        bool includeCurrentWeight,
        bool includeIdealWeight
    ) external view returns (DataTypes.VaultInfo[] memory);

    /// @notice Returns the current vault price oracle
    function getPriceOracle() external view returns (IUSDPriceOracle);

    /// @notice Set the vault price oracle
    function setPriceOracle(address priceOracle) external;
}
