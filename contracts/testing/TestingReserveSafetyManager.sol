// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../ReserveSafetyManager.sol";

contract TestingReserveSafetyManager is ReserveSafetyManager {
    constructor(
        uint256 _maxAllowedVaultDeviation,
        uint256 _stablecoinMaxDeviation,
        uint256 _minTokenPrice,
        IVault _balancerVault,
        IUSDPriceOracle _priceOracle,
        IAssetRegistry _assetRegistry
    )
        ReserveSafetyManager(
            _maxAllowedVaultDeviation,
            _stablecoinMaxDeviation,
            _minTokenPrice,
            _balancerVault,
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

    function buildMetaData(VaultWithAmount[] memory vaultsWithAmount)
        external
        pure
        returns (MetaData memory metaData)
    {
        return _buildMetaData(vaultsWithAmount);
    }

    function calculateImpliedPoolWeights(VaultWithAmount[] memory vaultsWithAmount)
        external
        pure
        returns (uint256[] memory)
    {
        return _calculateIdealWeights(vaultsWithAmount);
    }

    function checkVaultsWithinEpsilon(MetaData memory metaData)
        external
        view
        returns (bool, bool[] memory)
    {
        return _checkVaultsWithinEpsilon(metaData);
    }

    function individualVaultInspector(VaultWithAmount memory vaultWithAmount)
        external
        view
        returns (bool, bool)
    {
        return _individualVaultInspector(vaultWithAmount);
    }

    function allVaultsInspector(VaultWithAmount[] memory vaultsWithAmount)
        external
        view
        returns (
            bool,
            bool[] memory,
            bool,
            bool[] memory
        )
    {
        return _allVaultsInspector(vaultsWithAmount);
    }

    function checkUnhealthyMovesToIdeal(
        MetaData memory metaData,
        bool[] memory vaultStablecoinsOnPeg
    ) external pure returns (bool) {
        return _checkUnhealthyMovesToIdeal(metaData, vaultStablecoinsOnPeg);
    }

    function safeToMintOutsideEpsilon(
        MetaData memory metaData,
        bool[] memory vaultsWithinEpsilon,
        bool[] memory vaultStablecoinsOnPeg
    ) external pure returns (bool) {
        return _safeToMintOutsideEpsilon(metaData, vaultsWithinEpsilon, vaultStablecoinsOnPeg);
    }
}
