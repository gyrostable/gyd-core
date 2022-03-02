// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../safety/ReserveSafetyManager.sol";
import "../../libraries/DataTypes.sol";

contract TestingReserveSafetyManager is ReserveSafetyManager {
    constructor(
        uint256 _maxAllowedVaultDeviation,
        uint256 _stablecoinMaxDeviation,
        uint256 _minTokenPrice,
        IUSDPriceOracle _priceOracle,
        IAssetRegistry _assetRegistry,
        IVaultManager _vaultManager
    )
        ReserveSafetyManager(
            _maxAllowedVaultDeviation,
            _stablecoinMaxDeviation,
            _minTokenPrice,
            _priceOracle,
            _assetRegistry,
            _vaultManager
        )
    {}

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
