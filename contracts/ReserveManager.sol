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
    IGyroConfig public immutable gyroConfig;

    constructor(IGyroConfig _gyroConfig) {
        vaultRegistry = _gyroConfig.getVaultRegistry();
        reserveAddress = _gyroConfig.getAddress(ConfigKeys.RESERVE_ADDRESS);

        require(address(vaultRegistry) != address(0), Errors.INVALID_ARGUMENT);
        require(address(vaultRegistry) != address(0), Errors.INVALID_ARGUMENT);

        gyroConfig = _gyroConfig;
    }

    /// @inheritdoc IReserveManager
    function getReserveState() public view returns (DataTypes.ReserveState memory) {
        address[] memory vaultAddresses = vaultRegistry.listVaults();
        require(vaultAddresses.length > 0, Errors.INVALID_ARGUMENT);

        uint256 length = vaultAddresses.length;
        DataTypes.VaultInfo[] memory vaultsInfo = new DataTypes.VaultInfo[](length);

        for (uint256 i = 0; i < length; i++) {
            DataTypes.PersistedVaultMetadata memory persistedMetadata;
            persistedMetadata = vaultRegistry.getVaultMetadata(vaultAddresses[i]);

            uint256 reserveBalance = IERC20(vaultAddresses[i]).balanceOf(reserveAddress);

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
                decimals: IERC20Metadata(vaultAddresses[i]).decimals(),
                persistedMetadata: persistedMetadata,
                reserveBalance: reserveBalance,
                price: 0,
                currentWeight: 0,
                idealWeight: 0,
                pricedTokens: pricedTokens
            });
        }

        vaultsInfo = gyroConfig.getRootPriceOracle().fetchPricesUSD(vaultsInfo);

        uint256 reserveUSDValue = 0;
        uint256[] memory usdValues = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 usdValue = vaultsInfo[i].price.mulDown(vaultsInfo[i].reserveBalance);
            usdValues[i] = usdValue;
            reserveUSDValue += usdValue;
        }
        for (uint256 i = 0; i < length; i++) {
            /// Only zero at initialization
            vaultsInfo[i].currentWeight = reserveUSDValue == 0
                ? vaultsInfo[i].persistedMetadata.initialWeight
                : usdValues[i].divDown(reserveUSDValue);
        }

        uint256 returnsSum = 0;
        uint256[] memory weightedReturns = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            uint256 initialPrice = vaultsInfo[i].persistedMetadata.initialPrice;
            if (initialPrice == 0) continue;
            weightedReturns[i] = vaultsInfo[i].price.divDown(initialPrice).mulDown(
                vaultsInfo[i].persistedMetadata.initialWeight
            );
            returnsSum += weightedReturns[i];
        }

        // only 0 at initialization
        if (returnsSum > 0) {
            for (uint256 i = 0; i < length; i++) {
                vaultsInfo[i].idealWeight = weightedReturns[i].divDown(returnsSum);
            }
        }

        return DataTypes.ReserveState({vaults: vaultsInfo, totalUSDValue: reserveUSDValue});
    }

    function registerVault(
        address _addressOfVault,
        uint256 initialWeight,
        uint256 shortFlowMemory,
        uint256 shortFlowThreshold
    ) external governanceOnly {
        DataTypes.PersistedVaultMetadata memory persistedVaultMetadata = DataTypes
            .PersistedVaultMetadata({
                initialPrice: 0,
                initialWeight: initialWeight,
                shortFlowMemory: shortFlowMemory,
                shortFlowThreshold: shortFlowThreshold
            });

        vaultRegistry.registerVault(_addressOfVault, persistedVaultMetadata);

        DataTypes.ReserveState memory reserveState = getReserveState();
        uint256 initialVaultPrice = 0;
        for (uint256 i = 0; i < reserveState.vaults.length; i++) {
            if (reserveState.vaults[i].vault == _addressOfVault) {
                initialVaultPrice = reserveState.vaults[i].price;
            }
        }
        vaultRegistry.setInitialPrice(_addressOfVault, initialVaultPrice);
    }
}
