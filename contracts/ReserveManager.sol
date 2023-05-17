// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../libraries/FixedPoint.sol";
import "../libraries/ConfigHelpers.sol";
import "../libraries/DecimalScale.sol";
import "../libraries/ConfigKeys.sol";

import "../interfaces/IReserveManager.sol";
import "../interfaces/oracles/IBatchVaultPriceOracle.sol";
import "../interfaces/IVaultRegistry.sol";
import "../interfaces/IAssetRegistry.sol";
import "../interfaces/IGyroConfig.sol";
import "../interfaces/IGyroVault.sol";

import "./auth/Governable.sol";

contract ReserveManager is IReserveManager, Governable {
    using FixedPoint for uint256;
    using ConfigHelpers for IGyroConfig;
    using DecimalScale for uint256;

    uint256 public constant VAULT_DUST_THRESHOLD = 100e18;

    IVaultRegistry public immutable vaultRegistry;
    IAssetRegistry public immutable assetRegistry;
    address public immutable reserveAddress;
    IGyroConfig public immutable gyroConfig;

    constructor(address governor, IGyroConfig _gyroConfig) Governable(governor) {
        vaultRegistry = _gyroConfig.getVaultRegistry();
        assetRegistry = _gyroConfig.getAssetRegistry();
        reserveAddress = address(_gyroConfig.getReserve());

        require(address(vaultRegistry) != address(0), Errors.INVALID_ARGUMENT);
        require(address(assetRegistry) != address(0), Errors.INVALID_ARGUMENT);
        require(reserveAddress != address(0), Errors.INVALID_ARGUMENT);

        gyroConfig = _gyroConfig;
    }

    /// @inheritdoc IReserveManager
    function getReserveState() public view returns (DataTypes.ReserveState memory) {
        address[] memory vaultAddresses = vaultRegistry.listVaults();
        if (vaultAddresses.length == 0) {
            return DataTypes.ReserveState({vaults: new DataTypes.VaultInfo[](0), totalUSDValue: 0});
        }

        uint256 length = vaultAddresses.length;
        DataTypes.VaultInfo[] memory vaultsInfo = new DataTypes.VaultInfo[](length);

        for (uint256 i = 0; i < length; i++) {
            DataTypes.PersistedVaultMetadata memory persistedMetadata;
            persistedMetadata = vaultRegistry.getVaultMetadata(vaultAddresses[i]);

            IERC20Metadata vault = IERC20Metadata(vaultAddresses[i]);
            uint256 reserveBalance = vault.balanceOf(reserveAddress);
            reserveBalance = reserveBalance.scaleFrom(vault.decimals());

            IERC20[] memory tokens = IGyroVault(vaultAddresses[i]).getTokens();
            DataTypes.PricedToken[] memory pricedTokens = new DataTypes.PricedToken[](
                tokens.length
            );
            for (uint256 j = 0; j < tokens.length; j++) {
                pricedTokens[j] = DataTypes.PricedToken({
                    tokenAddress: address(tokens[j]),
                    isStable: assetRegistry.isAssetStable(address(tokens[j])),
                    price: 0
                });
            }

            vaultsInfo[i] = DataTypes.VaultInfo({
                vault: vaultAddresses[i],
                decimals: IERC20Metadata(vaultAddresses[i]).decimals(),
                underlying: IGyroVault(vaultAddresses[i]).underlying(),
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
                ? vaultsInfo[i].persistedMetadata.targetWeight
                : usdValues[i].divDown(reserveUSDValue);
        }

        uint256 returnsSum = 0;
        uint256[] memory weightedReturns = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            uint256 initialPrice = vaultsInfo[i].persistedMetadata.initialPrice;
            if (initialPrice == 0) continue;
            weightedReturns[i] = vaultsInfo[i].price.divDown(initialPrice).mulDown(
                vaultsInfo[i].persistedMetadata.targetWeight
            );
            returnsSum += weightedReturns[i];
        }

        // only 0 at initialization
        if (returnsSum > 0) {
            uint256 totalIdealWeight = 0;
            for (uint256 i = 0; i < length; i++) {
                uint256 idealWeight = weightedReturns[i].divUp(returnsSum);
                if (totalIdealWeight + idealWeight > FixedPoint.ONE) {
                    idealWeight = FixedPoint.ONE - totalIdealWeight;
                }
                vaultsInfo[i].idealWeight = idealWeight;
                totalIdealWeight += idealWeight;
            }
        }

        return DataTypes.ReserveState({vaults: vaultsInfo, totalUSDValue: reserveUSDValue});
    }

    function setVaults(DataTypes.VaultConfiguration[] calldata vaults) external governanceOnly {
        _ensureValuableVaultsNotRemoved(vaults);

        DataTypes.VaultInternalConfiguration[]
            memory vaultConfigs = new DataTypes.VaultInternalConfiguration[](vaults.length);
        for (uint256 i; i < vaults.length; i++) {
            vaultConfigs[i] = _makeVaultInternalConfiguration(vaults[i]);
        }

        vaultRegistry.setVaults(vaultConfigs);

        DataTypes.ReserveState memory reserveState = getReserveState();
        for (uint256 i = 0; i < reserveState.vaults.length; i++) {
            vaultRegistry.setInitialPrice(
                reserveState.vaults[i].vault,
                reserveState.vaults[i].price
            );
        }
    }

    function _makeVaultInternalConfiguration(DataTypes.VaultConfiguration calldata vaultConfig)
        internal
        pure
        returns (DataTypes.VaultInternalConfiguration memory)
    {
        return
            DataTypes.VaultInternalConfiguration({
                vaultAddress: vaultConfig.vaultAddress,
                metadata: DataTypes.PersistedVaultMetadata({
                    initialPrice: 0,
                    targetWeight: vaultConfig.targetWeight,
                    shortFlowMemory: vaultConfig.shortFlowMemory,
                    shortFlowThreshold: vaultConfig.shortFlowThreshold
                })
            });
    }

    function _ensureValuableVaultsNotRemoved(DataTypes.VaultConfiguration[] memory vaults)
        internal
        view
    {
        DataTypes.ReserveState memory previousState = getReserveState();
        for (uint256 i; i < previousState.vaults.length; i++) {
            DataTypes.VaultInfo memory vaultInfo = previousState.vaults[i];
            require(!_isValuableVaultRemoved(vaultInfo, vaults), Errors.VAULT_CANNOT_BE_REMOVED);
        }
    }

    function _isValuableVaultRemoved(
        DataTypes.VaultInfo memory vaultInfo,
        DataTypes.VaultConfiguration[] memory vaults
    ) internal pure returns (bool) {
        for (uint256 j; j < vaults.length; j++) {
            if (vaultInfo.vault == vaults[j].vaultAddress) return false;
        }
        uint256 vaultUSDAmount = vaultInfo.price.mulDown(vaultInfo.reserveBalance);
        return vaultUSDAmount >= VAULT_DUST_THRESHOLD;
    }
}
