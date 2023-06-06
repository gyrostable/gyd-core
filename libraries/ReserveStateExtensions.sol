// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "../interfaces/oracles/IBatchVaultPriceOracle.sol";
import "../interfaces/IGyroVault.sol";
import "./DataTypes.sol";
import "./FixedPoint.sol";
import "./DecimalScale.sol";

library ReserveStateExtensions {
    using FixedPoint for uint256;
    using DecimalScale for uint256;

    /// @notice a stablecoin should be equal to 1 USD
    uint256 public constant STABLECOIN_IDEAL_PRICE = 1e18;

    function computeLowerBoundUSDValue(
        DataTypes.ReserveState memory state,
        IBatchVaultPriceOracle oracle
    ) internal view returns (uint256) {
        uint256 reserveValue;
        for (uint256 i; i < state.vaults.length; i++) {
            DataTypes.VaultInfo memory vaultInfo = state.vaults[i];
            uint256 lowerBoundPrice = computeLowerBoundUSDPrice(vaultInfo, oracle);
            uint256 scaledBalance = vaultInfo.reserveBalance.scaleFrom(vaultInfo.decimals);
            reserveValue += scaledBalance.mulDown(lowerBoundPrice);
        }
        return reserveValue;
    }

    function computeLowerBoundUSDPrice(
        DataTypes.VaultInfo memory vaultInfo,
        IBatchVaultPriceOracle oracle
    ) internal view returns (uint256) {
        DataTypes.PricedToken[] memory pricedTokens = _clampPricedTokens(
            vaultInfo.pricedTokens,
            false
        );
        return oracle.getVaultPrice(IGyroVault(vaultInfo.vault), pricedTokens);
    }

    function computeUpperBoundUSDPrice(
        DataTypes.VaultInfo memory vaultInfo,
        IBatchVaultPriceOracle oracle
    ) internal view returns (uint256) {
        DataTypes.PricedToken[] memory pricedTokens = _clampPricedTokens(
            vaultInfo.pricedTokens,
            true
        );
        return oracle.getVaultPrice(IGyroVault(vaultInfo.vault), pricedTokens);
    }

    function _clampPricedTokens(DataTypes.PricedToken[] memory tokens, bool clampAbove)
        internal
        pure
        returns (DataTypes.PricedToken[] memory)
    {
        DataTypes.PricedToken[] memory protocolPricedTokens = new DataTypes.PricedToken[](
            tokens.length
        );
        for (uint256 i = 0; i < tokens.length; i++) {
            protocolPricedTokens[i].tokenAddress = tokens[i].tokenAddress;
            protocolPricedTokens[i].isStable = tokens[i].isStable;
            if (tokens[i].isStable && clampAbove == tokens[i].price < STABLECOIN_IDEAL_PRICE)
                protocolPricedTokens[i].price = STABLECOIN_IDEAL_PRICE;
            else protocolPricedTokens[i].price = tokens[i].price;
        }
        return protocolPricedTokens;
    }
}
