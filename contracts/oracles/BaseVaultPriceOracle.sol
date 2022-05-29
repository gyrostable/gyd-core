// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../../interfaces/oracles/IVaultPriceOracle.sol";

import "../../libraries/FixedPoint.sol";

abstract contract BaseVaultPriceOracle is IVaultPriceOracle {
    using FixedPoint for uint256;

    /// @inheritdoc IVaultPriceOracle
    function getPriceUSD(IGyroVault vault, DataTypes.PricedToken[] memory underlyingPricedTokens)
        external
        view
        returns (uint256)
    {
        uint256 poolTokenPriceUSD = getPoolTokenPriceUSD(vault, underlyingPricedTokens);
        return poolTokenPriceUSD.mulDown(vault.exchangeRate());
    }

    /// @notice returns the price of the underlying pool token (e.g. BPT token)
    /// rather than the price of the vault token itself
    function getPoolTokenPriceUSD(
        IGyroVault vaultAddress,
        DataTypes.PricedToken[] memory underlyingPricedTokens
    ) public view virtual returns (uint256);
}
