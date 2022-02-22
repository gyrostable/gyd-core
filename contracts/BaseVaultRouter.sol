// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../libraries/DataTypes.sol";
import "../interfaces/IGyroVaultRouter.sol";
import "../interfaces/IGyroVault.sol";
import "../interfaces/ILPTokenExchangerRegistry.sol";
import "../interfaces/ILPTokenExchanger.sol";

/// @title Base implementation of IVaultRouter containing logic to manage vaults
abstract contract BaseVaultRouter is IGyroVaultRouter {
    ILPTokenExchangerRegistry internal exchangerRegistry;

    address[] internal vaults;

    /// @dev maps an underlying token (e.g. DAI) and returns the vaults where it is contained
    mapping(address => address[]) internal vaultsIncludingToken;

    constructor(address exchangerRegistryAddress) {
        exchangerRegistry = ILPTokenExchangerRegistry(exchangerRegistryAddress);
    }

    /// @inheritdoc IGyroVaultRouter
    function addVault(address vaultAddress) external override {
        vaults.push(vaultAddress);
        address[] memory supportedTokens = getTokensSupportedByVault(vaultAddress);
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            vaultsIncludingToken[supportedTokens[i]].push(vaultAddress);
        }
    }

    /// @inheritdoc IGyroVaultRouter
    function removeVault(address vaultAddress) external override {
        for (uint256 i = 0; i < vaults.length; i++) {
            if (vaults[i] == vaultAddress) {
                vaults[i] = vaults[vaults.length - 1];
                vaults.pop();
                return;
            }
        }

        address[] memory supportedTokens = getTokensSupportedByVault(vaultAddress);
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            address token = supportedTokens[i];
            address[] storage currentVaultsSupportingToken = vaultsIncludingToken[token];
            uint256 vaultsCount = currentVaultsSupportingToken.length;
            for (uint256 j = 0; j < vaultsCount; j++) {
                if (currentVaultsSupportingToken[j] == vaultAddress) {
                    currentVaultsSupportingToken[j] = currentVaultsSupportingToken[vaultsCount - 1];
                    currentVaultsSupportingToken.pop();
                    break;
                }
            }
        }
    }

    function getTokensSupportedByVault(address vaultAddress)
        internal
        view
        returns (address[] memory)
    {
        address lpToken = IGyroVault(vaultAddress).underlying();
        ILPTokenExchanger exchanger = exchangerRegistry.getTokenExchanger(lpToken);
        return exchanger.getSupportedTokens();
    }

    /// @inheritdoc IGyroVaultRouter
    function supportedVaults() external view override returns (address[] memory) {
        return vaults;
    }
}
