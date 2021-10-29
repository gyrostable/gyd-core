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
    function computeInputRoutes(DataTypes.MonetaryAmount[] memory inputMonetaryAmounts)
        external
        view
        override
        returns (DataTypes.TokenToVaultMapping[] memory)
    {
        DataTypes.TokenToVaultMapping[] memory routes = new DataTypes.TokenToVaultMapping[](
            inputMonetaryAmounts.length
        );
        for (uint256 i = 0; i < inputMonetaryAmounts.length; i++) {
            DataTypes.MonetaryAmount memory inputMonetaryAmount = inputMonetaryAmounts[i];
            address vault = selectVaultForToken(inputMonetaryAmount.tokenAddress);
            routes[i] = DataTypes.TokenToVaultMapping({
                inputToken: inputMonetaryAmount.tokenAddress,
                vault: vault
            });
        }
        return routes;
    }

    /// @dev this is a dummy selection that returns a "random" vault based on the current timestamp
    function selectVaultForToken(address tokenAddress) internal view returns (address) {
        address[] memory vaults = vaultsIncludingToken[tokenAddress];
        return vaults[block.timestamp % vaults.length];
    }
}
