pragma solidity ^0.8.4;

import "../../libraries/DataTypes.sol";
import "../../interfaces/IVaultRouter.sol";
import "../../interfaces/IVault.sol";
import "../../interfaces/ILPTokenExchangerRegistry.sol";
import "../../interfaces/ILPTokenExchanger.sol";
import "../BaseVaultRouter.sol";

/// @title Mock implementation of IVaultRouter
contract MockLPTokenExchanger {
    function getSupportedTokens() external view returns (address[] memory) {
        // address[] memory supportedTokens = []
    }

    function deposit(DataTypes.TokenAmount memory underlyingTokenAmount, address lpToken)
        external
        returns (uint256 lpTokenAmount)
    {
        return block.timestamp;
    }
}
