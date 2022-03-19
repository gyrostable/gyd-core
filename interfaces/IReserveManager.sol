// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../interfaces/IVaultWeightManager.sol";
import "../interfaces/oracles/IUSDPriceOracle.sol";
import "../libraries/DataTypes.sol";

interface IReserveManager {
    event NewVaultWeightManager(address indexed oldManager, address indexed newManager);
    event NewPriceOracle(address indexed oldOracle, address indexed newOracle);

    struct ReserveStateOptions {
        bool includeMetadata;
        bool includePrice;
        bool includeCurrentWeight;
        bool includeIdealWeight;
    }

    /// @notice Returns a list of vaults without including any metadata
    function getReserveState() external view returns (DataTypes.ReserveState memory);

    /// @notice Returns a list of vaults with requested metadata
    /// @param options allows the caller to specify what they want to be included in
    /// the returned reserve state. If no options are passed, the full reserve state
    /// is returned.
    function getReserveState(ReserveStateOptions memory options)
        external
        view
        returns (DataTypes.ReserveState memory);
}
