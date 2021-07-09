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
    function computeInputRoutes(DataTypes.TokenAmount[] memory inputTokenAmounts)
        external
        view
        override
        returns (DataTypes.Route[] memory)
    {
        DataTypes.Route[] memory routes = new DataTypes.Route[](inputTokenAmounts.length);
        for (uint256 i = 0; i < inputTokenAmounts.length; i++) {
            DataTypes.TokenAmount memory inputTokenAmount = inputTokenAmounts[i];
            address vault = selectVaultForToken(inputTokenAmount.token);
            routes[i] = DataTypes.Route({tokenAmount: inputTokenAmount, vaultAddress: vault});
        }
        return routes;
    }

    /// @dev this is a dummy selection that returns a "random" vault based on the current timestamp
    function selectVaultForToken(address tokenAddress) internal view returns (address) {
        address[] memory vaults = vaultsIncludingToken[tokenAddress];
        return vaults[block.timestamp % vaults.length];
    }
}
