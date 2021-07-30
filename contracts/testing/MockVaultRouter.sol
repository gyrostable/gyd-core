// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../../libraries/DataTypes.sol";
import "../../interfaces/IVaultRouter.sol";
import "../../interfaces/IVault.sol";
import "../../interfaces/ILPTokenExchangerRegistry.sol";
import "../../interfaces/ILPTokenExchanger.sol";
import "../BaseVaultRouter.sol";

/// @title Mock implementation of IVaultRouter
abstract contract MockVaultRouter is BaseVaultRouter {
    /// @inheritdoc IVaultRouter
    function computeInputRoutes(DataTypes.TokenTuple[] memory inputTokenTuples)
        external
        view
        override
        returns (DataTypes.Route[] memory)
    {
        DataTypes.Route[] memory routes = new DataTypes.Route[](inputTokenTuples.length);
        for (uint256 i = 0; i < inputTokenTuples.length; i++) {
            DataTypes.TokenTuple memory inputTokenTuple = inputTokenTuples[i];
            address vault = selectVaultForToken(inputTokenTuple.tokenAddress);
            routes[i] = DataTypes.Route({tokenTuple: inputTokenTuple, vaultAddress: vault});
        }
        return routes;
    }

    /// @dev this is a dummy selection that returns a "random" vault based on the current timestamp
    function selectVaultForToken(address tokenAddress) internal view returns (address) {
        address[] memory vaults = vaultsIncludingToken[tokenAddress];
        return vaults[block.timestamp % vaults.length];
    }
}
