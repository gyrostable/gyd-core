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
            reserveValue += computeLowerBoundUSDValue(state.vaults[i], oracle);
        }
        return reserveValue;
    }

    function computeLowerBoundUSDValue(
        DataTypes.VaultWithAmount memory vaultWithAmount,
        IBatchVaultPriceOracle oracle
    ) internal view returns (uint256) {
        DataTypes.VaultInfo memory vaultInfo = vaultWithAmount.vaultInfo;
        DataTypes.PricedToken[] memory pricedTokens = _toLowerBoundPricedTokens(
            vaultInfo.pricedTokens
        );
        uint256 vaultPrice = oracle.getVaultPrice(IGyroVault(vaultInfo.vault), pricedTokens);
        return vaultPrice.mulDown(vaultWithAmount.amount.scaleFrom(vaultInfo.decimals));
    }

    function computeLowerBoundUSDValue(
        DataTypes.VaultInfo memory vaultInfo,
        IBatchVaultPriceOracle oracle
    ) internal view returns (uint256) {
        DataTypes.PricedToken[] memory pricedTokens = _toLowerBoundPricedTokens(
            vaultInfo.pricedTokens
        );
        uint256 vaultPrice = oracle.getVaultPrice(IGyroVault(vaultInfo.vault), pricedTokens);
        return vaultPrice.mulDown(vaultInfo.reserveBalance.scaleFrom(vaultInfo.decimals));
    }

    function _toLowerBoundPricedTokens(
        DataTypes.PricedToken[] memory tokens
    ) internal pure returns (DataTypes.PricedToken[] memory) {
        DataTypes.PricedToken[] memory protocolPricedTokens = new DataTypes.PricedToken[](
            tokens.length
        );
        for (uint256 i = 0; i < tokens.length; i++) {
            protocolPricedTokens[i].tokenAddress = tokens[i].tokenAddress;
            protocolPricedTokens[i].isStable = tokens[i].isStable;
            protocolPricedTokens[i].price = tokens[i].price < STABLECOIN_IDEAL_PRICE
                ? tokens[i].price
                : STABLECOIN_IDEAL_PRICE;
        }
        return protocolPricedTokens;
    }
}
