// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../interfaces/IVaultWeightManager.sol";
import "./auth/Governable.sol";

contract StaticVaultWeightManager is IVaultWeightManager, Governable {
    mapping(address => uint256) _vaultWeights;

    /// @inheritdoc IVaultWeightManager
    function getVaultWeight(address _vault) external view override returns (uint256) {
        return _vaultWeights[_vault];
    }

    /// @inheritdoc IVaultWeightManager
    function getVaultWeights(address[] calldata _vaults)
        external
        view
        override
        returns (uint256[] memory)
    {
        uint256[] memory result = new uint256[](_vaults.length);
        for (uint256 i = 0; i < _vaults.length; i++) {
            result[i] = _vaultWeights[_vaults[i]];
        }
        return result;
    }

    /// @inheritdoc IVaultWeightManager
    function setVaultWeight(address _vault, uint256 _weight) external override governanceOnly {
        _vaultWeights[_vault] = _weight;
    }
}
