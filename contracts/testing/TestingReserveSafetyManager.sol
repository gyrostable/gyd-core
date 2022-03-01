// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../safety/ReserveSafetyManager.sol";

contract TestingReserveSafetyManager is ReserveSafetyManager {
    constructor(
        uint256 _maxAllowedVaultDeviation,
        uint256 _stablecoinMaxDeviation,
        uint256 _minTokenPrice,
        IUSDPriceOracle _priceOracle,
        IAssetRegistry _assetRegistry
    )
        ReserveSafetyManager(
            _maxAllowedVaultDeviation,
            _stablecoinMaxDeviation,
            _minTokenPrice,
            _priceOracle,
            _assetRegistry
        )
    {}

    function calculateWeightsAndTotal(uint256[] memory amounts, uint256[] memory prices)
        external
        pure
        returns (uint256[] memory, uint256)
    {
        return _calculateWeightsAndTotal(amounts, prices);
    }

    function buildMetaData(Order memory order) external pure returns (MetaData memory metaData) {
        return _buildMetaData(order);
    }

    function calculateIdealWeights(VaultWithAmount[] memory vaultsWithAmount)
        external
        pure
        returns (uint256[] memory)
    {
        return _calculateIdealWeights(vaultsWithAmount);
    }

    function updateMetaDataWithEpsilonStatus(MetaData memory metaData)
        external
        view
        returns (MetaData memory)
    {
        _updateMetaDataWithEpsilonStatus(metaData);
        return metaData;
    }

    function updateVaultWithPriceSafety(VaultMetadata memory vaultData)
        external
        view
        returns (VaultMetadata memory)
    {
        _updateVaultWithPriceSafety(vaultData);
        return vaultData;
    }

    function updateMetadataWithPriceSafety(MetaData memory metaData)
        external
        view
        returns (MetaData memory)
    {
        _updateMetadataWithPriceSafety(metaData);
        return metaData;
    }

    function vaultWeightWithOffPegFalls(MetaData memory metaData) external pure returns (bool) {
        return _vaultWeightWithOffPegFalls(metaData);
    }

    function safeToExecuteOutsideEpsilon(MetaData memory metaData) external pure returns (bool) {
        return _safeToExecuteOutsideEpsilon(metaData);
    }
}
