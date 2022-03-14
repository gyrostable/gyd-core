// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../libraries/FixedPoint.sol";
import "../libraries/ConfigHelpers.sol";
import "../libraries/ConfigKeys.sol";

import "../interfaces/IReserveManager.sol";
import "../interfaces/oracles/IBatchVaultPriceOracle.sol";
import "../interfaces/IVaultRegistry.sol";
import "../interfaces/IGyroConfig.sol";
import "../interfaces/IGyroVault.sol";

import "./auth/Governable.sol";

contract ReserveManager is IReserveManager, Governable {
    using FixedPoint for uint256;
    using ConfigHelpers for IGyroConfig;

    IVaultRegistry public immutable vaultRegistry;
    address public immutable reserveAddress;

    IBatchVaultPriceOracle internal priceOracle;

    constructor(IGyroConfig _gyroConfig) {
        vaultRegistry = _gyroConfig.getVaultRegistry();
        reserveAddress = _gyroConfig.getAddress(ConfigKeys.RESERVE_ADDRESS);
        // priceOracle = _gyroConfig.getRootPriceOracle();
    }

    /// @inheritdoc IReserveManager
    function getReserveState() external view returns (DataTypes.ReserveState memory) {
        ReserveStateOptions memory options = ReserveStateOptions({
            includeMetadata: true,
            includePrice: true,
            includeCurrentWeight: true,
            includeIdealWeight: true
        });
        return getReserveState(options);
    }

    function getReserveState(ReserveStateOptions memory options)
        public
        view
        returns (DataTypes.ReserveState memory)
    {
        require(!options.includeCurrentWeight || options.includePrice, Errors.INVALID_ARGUMENT);

        address[] memory vaultAddresses = vaultRegistry.listVaults();

        uint256 length = vaultAddresses.length;
        DataTypes.VaultInfo[] memory vaultsInfo = new DataTypes.VaultInfo[](length);

        for (uint256 i = 0; i < length; i++) {
            DataTypes.PersistedVaultMetadata memory persistedMetadata;
            if (options.includeMetadata) {
                persistedMetadata = vaultRegistry.getVaultMetadata(vaultAddresses[i]);
            }

            uint256 reserveBalance = options.includeCurrentWeight
                ? IERC20(vaultAddresses[i]).balanceOf(reserveAddress)
                : 0;

            IERC20[] memory tokens = IGyroVault(vaultAddresses[i]).getTokens();
            DataTypes.PricedToken[] memory pricedTokens = new DataTypes.PricedToken[](
                tokens.length
            );
            for (uint256 j = 0; j < tokens.length; j++) {
                pricedTokens[j] = DataTypes.PricedToken({
                    tokenAddress: address(tokens[j]),
                    price: 0
                });
            }

            vaultsInfo[i] = DataTypes.VaultInfo({
                vault: vaultAddresses[i],
                persistedMetadata: persistedMetadata,
                reserveBalance: reserveBalance,
                price: 0,
                currentWeight: 0,
                idealWeight: 0,
                pricedTokens: pricedTokens
            });
        }

        if (options.includePrice) {
            vaultsInfo = priceOracle.fetchPricesUSD(vaultsInfo);
        }

        uint256 reserveUSDValue = 0;
        if (options.includeCurrentWeight) {
            uint256[] memory usdValues = new uint256[](length);
            for (uint256 i = 0; i < length; i++) {
                uint256 usdValue = vaultsInfo[i].price.mulDown(vaultsInfo[i].reserveBalance);
                usdValues[i] = usdValue;
                reserveUSDValue += usdValue;
            }
            for (uint256 i = 0; i < length; i++) {
                vaultsInfo[i].currentWeight = reserveUSDValue == 0
                    ? vaultsInfo[i].persistedMetadata.initialWeight
                    : usdValues[i].divDown(reserveUSDValue);
            }
        }

        if (options.includeIdealWeight) {
            uint256 returnsSum = 0;
            uint256[] memory weightedReturns = new uint256[](length);
            for (uint256 i = 0; i < length; i++) {
                weightedReturns[i] = (vaultsInfo[i].price)
                    .divDown(vaultsInfo[i].persistedMetadata.initialPrice)
                    .mulDown(vaultsInfo[i].persistedMetadata.initialWeight);
                returnsSum += weightedReturns[i];
            }
            for (uint256 i = 0; i < length; i++) {
                vaultsInfo[i].idealWeight = weightedReturns[i].divDown(returnsSum);
            }
        }

        return DataTypes.ReserveState({vaults: vaultsInfo, totalUSDValue: reserveUSDValue});
    }
}
