// SPDX-License-Identifier: for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>. 
pragma solidity ^0.8.4;

import "../auth/Governable.sol";

import "../../libraries/DataTypes.sol";
import "../../libraries/Arrays.sol";
import "../../libraries/Vaults.sol";

import "../../interfaces/oracles/IUSDBatchPriceOracle.sol";
import "../../interfaces/oracles/IVaultPriceOracle.sol";
import "../../interfaces/oracles/IBatchVaultPriceOracle.sol";

contract BatchVaultPriceOracle is IBatchVaultPriceOracle, Governable {
    using Arrays for address[];

    IUSDBatchPriceOracle public batchPriceOracle;

    mapping(Vaults.Type => IVaultPriceOracle) public vaultPriceOracles;

    constructor(IUSDBatchPriceOracle _batchPriceOracle) {
        require(address(_batchPriceOracle) != address(0), Errors.INVALID_ARGUMENT);
        batchPriceOracle = _batchPriceOracle;
    }

    function registerVaultPriceOracle(Vaults.Type vaultType, IVaultPriceOracle priceOracle)
        external
        governanceOnly
    {
        vaultPriceOracles[vaultType] = priceOracle;
        emit VaultPriceOracleChanged(vaultType, address(priceOracle));
    }

    function fetchPricesUSD(DataTypes.VaultInfo[] memory vaultsInfo)
        external
        view
        returns (DataTypes.VaultInfo[] memory)
    {
        address[] memory tokens = _constructTokensArray(vaultsInfo);
        uint256[] memory underlyingPrices = batchPriceOracle.getPricesUSD(tokens);

        for (uint256 i = 0; i < vaultsInfo.length; i++) {
            _assignUnderlyingTokenPrices(vaultsInfo[i], tokens, underlyingPrices);
            vaultsInfo[i].price = _getVaultPrice(vaultsInfo[i]);
        }

        return vaultsInfo;
    }

    function _getVaultPrice(DataTypes.VaultInfo memory vaultInfo) internal view returns (uint256) {
        IGyroVault vault = IGyroVault(vaultInfo.vault);
        IVaultPriceOracle vaultPriceOracle = vaultPriceOracles[vault.vaultType()];
        require(address(vaultPriceOracle) != address(0), Errors.ASSET_NOT_SUPPORTED);
        return vaultPriceOracle.getPriceUSD(vault, vaultInfo.pricedTokens);
    }

    function _assignUnderlyingTokenPrices(
        DataTypes.VaultInfo memory vaultInfo,
        address[] memory tokens,
        uint256[] memory underlyingPrices
    ) internal pure {
        for ((uint256 i, uint256 j) = (0, 0); i < vaultInfo.pricedTokens.length; i++) {
            while (tokens[j] != vaultInfo.pricedTokens[i].tokenAddress) j++;
            vaultInfo.pricedTokens[i].price = underlyingPrices[j];
        }
    }

    function _constructTokensArray(DataTypes.VaultInfo[] memory vaultsInfo)
        internal
        view
        returns (address[] memory)
    {
        uint256 tokensCount = 0;
        for (uint256 i = 0; i < vaultsInfo.length; i++) {
            tokensCount += vaultsInfo[i].pricedTokens.length;
        }
        address[] memory tokens = new address[](tokensCount);
        for ((uint256 i, uint256 k) = (0, 0); i < vaultsInfo.length; i++) {
            for (uint256 j = 0; j < vaultsInfo[i].pricedTokens.length; (j++, k++)) {
                tokens[k] = vaultsInfo[i].pricedTokens[j].tokenAddress;
            }
        }
        return tokens.sort().dedup();
    }
}
