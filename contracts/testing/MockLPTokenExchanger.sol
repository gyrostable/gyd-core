pragma solidity ^0.8.4;

import "OpenZeppelin/openzeppelin-contracts@4.1.0/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.1.0/contracts/token/ERC20/IERC20.sol";

import "../../libraries/DataTypes.sol";
import "../../interfaces/IVaultRouter.sol";
import "../../interfaces/IVault.sol";
import "../../interfaces/ILPTokenExchangerRegistry.sol";
import "../../interfaces/ILPTokenExchanger.sol";
import "../BaseVaultRouter.sol";

/// @title Mock implementation of IVaultRouter
contract MockLPTokenExchanger {
    using SafeERC20 for IERC20;

    function getSupportedTokens() external view returns (address[] memory) {
        // address[] memory supportedTokens = []
    }

    function deposit(DataTypes.TokenAmount memory underlyingTokenAmount)
        external
        returns (uint256 lpTokenAmount)
    {
        // IERC20.safeTransfer()
        return underlyingTokenAmount.amount;
    }

    function withdraw(DataTypes.TokenAmount memory lpTokenAmount)
        external
        returns (uint256 underlyingTokenAmount)
    {
        return lpTokenAmount.amount;
    }
}
