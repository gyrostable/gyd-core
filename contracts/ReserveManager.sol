// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../libraries/FixedPoint.sol";
import "../libraries/ConfigHelpers.sol";
import "../libraries/DecimalScale.sol";
import "../libraries/ConfigKeys.sol";
import "../libraries/VaultMetadataExtension.sol";

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
    using VaultMetadataExtension for DataTypes.PersistedVaultMetadata;

    uint256 public constant DEFAULT_VAULT_DUST_THRESHOLD = 500e18;

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

            IERC20[] memory tokens = IGyroVault(vaultAddresses[i]).getTokens();
            DataTypes.PricedToken[] memory pricedTokens = new DataTypes.PricedToken[](
                tokens.length
            );
            for (uint256 j = 0; j < tokens.length; j++) {
                bool isStable = assetRegistry.isAssetStable(address(tokens[j]));
                DataTypes.Range memory range;
                if (isStable) {
                    range = assetRegistry.getAssetRange(address(tokens[j]));
                }
                pricedTokens[j] = DataTypes.PricedToken({
                    tokenAddress: address(tokens[j]),
                    isStable: isStable,
                    price: 0,
                    priceRange: range
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
                targetWeight: 0,
                pricedTokens: pricedTokens
            });
        }

        vaultsInfo = gyroConfig.getRootPriceOracle().fetchPricesUSD(vaultsInfo);

        uint256 reserveUSDValue = 0;
        uint256[] memory usdValues = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            DataTypes.VaultInfo memory vaultInfo = vaultsInfo[i];
            uint256 scaledReserveBalance = vaultInfo.reserveBalance.scaleFrom(vaultInfo.decimals);
            uint256 usdValue = vaultsInfo[i].price.mulDown(scaledReserveBalance);
            usdValues[i] = usdValue;
            reserveUSDValue += usdValue;
        }
        for (uint256 i = 0; i < length; i++) {
            /// Only zero at initialization
            vaultsInfo[i].currentWeight = reserveUSDValue == 0
                ? vaultsInfo[i].persistedMetadata.scheduleWeight()
                : usdValues[i].divDown(reserveUSDValue);
        }

        uint256 returnsSum = 0;
        uint256[] memory weightedReturns = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            uint256 initialPrice = vaultsInfo[i].persistedMetadata.priceAtCalibration;
            if (initialPrice == 0) continue;
            weightedReturns[i] = vaultsInfo[i].price.divDown(initialPrice).mulDown(
                vaultsInfo[i].persistedMetadata.scheduleWeight()
            );
            returnsSum += weightedReturns[i];
        }

        // only 0 at initialization
        if (returnsSum > 0) {
            uint256 totaltargetWeight = 0;
            for (uint256 i = 0; i < length; i++) {
                uint256 targetWeight = weightedReturns[i].divUp(returnsSum);
                if (totaltargetWeight + targetWeight > FixedPoint.ONE) {
                    targetWeight = FixedPoint.ONE - totaltargetWeight;
                }
                vaultsInfo[i].targetWeight = targetWeight;
                totaltargetWeight += targetWeight;
            }
        }

        return DataTypes.ReserveState({vaults: vaultsInfo, totalUSDValue: reserveUSDValue});
    }

    function setVaults(DataTypes.VaultConfiguration[] calldata vaults) external governanceOnly {
        _ensureValuableVaultsNotRemoved(vaults);
        vaultRegistry.setVaults(vaults);
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
    ) internal view returns (bool) {
        for (uint256 j; j < vaults.length; j++) {
            if (vaultInfo.vault == vaults[j].vaultAddress) return false;
        }
        uint256 vaultUSDAmount = vaultInfo.price.mulDown(vaultInfo.reserveBalance);
        uint256 vaultDustThreshold = gyroConfig.getUint(
            ConfigKeys.VAULT_DUST_THRESHOLD,
            DEFAULT_VAULT_DUST_THRESHOLD
        );
        return vaultUSDAmount >= vaultDustThreshold;
    }
}
