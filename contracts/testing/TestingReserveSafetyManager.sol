// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.10;

import "../safety/ReserveSafetyManager.sol";
import "../../libraries/DataTypes.sol";

contract TestingReserveSafetyManager is ReserveSafetyManager {
    constructor(
        address _governor,
        uint256 _maxAllowedVaultDeviation,
        uint256 _minTokenPrice
    ) ReserveSafetyManager(_governor, _maxAllowedVaultDeviation, _minTokenPrice) {}

    function calculateWeightsAndTotal(uint256[] memory amounts, uint256[] memory prices)
        external
        pure
        returns (uint256[] memory, uint256)
    {
        return _calculateWeightsAndTotal(amounts, prices);
    }

    function buildMetaData(DataTypes.Order memory order)
        external
        pure
        returns (DataTypes.Metadata memory metaData)
    {
        return _buildMetaData(order);
    }

    function updateMetaDataWithEpsilonStatus(DataTypes.Metadata memory metaData)
        external
        view
        returns (DataTypes.Metadata memory)
    {
        _updateMetaDataWithEpsilonStatus(metaData);
        return metaData;
    }

    function updateVaultWithPriceSafety(DataTypes.VaultMetadata memory vaultData)
        external
        view
        returns (DataTypes.VaultMetadata memory)
    {
        _updateVaultWithPriceSafety(vaultData);
        return vaultData;
    }

    function updateMetadataWithPriceSafety(DataTypes.Metadata memory metaData)
        external
        view
        returns (DataTypes.Metadata memory)
    {
        _updateMetadataWithPriceSafety(metaData);
        return metaData;
    }

    function vaultWeightWithOffPegFalls(DataTypes.Metadata memory metaData)
        external
        pure
        returns (bool)
    {
        return _vaultWeightWithOffPegFalls(metaData);
    }

    function safeToExecuteOutsideEpsilon(DataTypes.Metadata memory metaData)
        external
        pure
        returns (bool)
    {
        return _safeToExecuteOutsideEpsilon(metaData);
    }
}
