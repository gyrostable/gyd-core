pragma solidity ^0.8.4;

import "OpenZeppelin/openzeppelin-contracts@4.1.0/contracts/token/ERC20/IERC20.sol";

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

    function depositFor(DataTypes.TokenTuple memory underlyingToken, address userAddress)
        external
        returns (uint256 lpTokenAmount)
    {
        IERC20(underlyingToken.tokenAddress).transferFrom(
            userAddress,
            address(this),
            underlyingToken.amount
        );
        return underlyingToken.amount / 2;
    }

    function withdrawFor(DataTypes.TokenTuple memory lpToken, address userAddress)
        external
        returns (uint256 underlyingTokenAmount)
    {
        IERC20(lpToken.tokenAddress).transferFrom(address(this), userAddress, lpToken.amount);
        return lpToken.amount;
    }
}
