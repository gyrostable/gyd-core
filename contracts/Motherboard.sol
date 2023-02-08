// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IFeeHandler.sol";
import "../interfaces/IMotherboard.sol";
import "../interfaces/IGyroVault.sol";
import "../interfaces/ILPTokenExchanger.sol";
import "../interfaces/IPAMM.sol";
import "../interfaces/IGyroConfig.sol";
import "../interfaces/IGYDToken.sol";
import "../interfaces/IFeeBank.sol";

import "../libraries/DataTypes.sol";
import "../libraries/ConfigKeys.sol";
import "../libraries/ConfigHelpers.sol";
import "../libraries/Errors.sol";
import "../libraries/FixedPoint.sol";
import "../libraries/DecimalScale.sol";

import "./auth/GovernableUpgradeable.sol";

/// @title MotherBoard is the central contract connecting the different pieces
/// of the Gyro protocol
contract Motherboard is IMotherboard, GovernableUpgradeable {
    using FixedPoint for uint256;
    using DecimalScale for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IGYDToken;
    using ConfigHelpers for IGyroConfig;

    uint256 internal constant _REDEEM_DEVIATION_EPSILON = 1e13; // 0.001 %

    /// @inheritdoc IMotherboard
    IGYDToken public immutable override gydToken;

    /// @inheritdoc IMotherboard
    IReserve public immutable override reserve;

    /// @inheritdoc IMotherboard
    IGyroConfig public immutable override gyroConfig;

    constructor(IGyroConfig _gyroConfig) {
        gyroConfig = _gyroConfig;
        gydToken = _gyroConfig.getGYDToken();
        reserve = _gyroConfig.getReserve();
        gydToken.safeApprove(address(_gyroConfig.getFeeBank()), type(uint256).max);
    }

    /// @inheritdoc IMotherboard
    function mint(DataTypes.MintAsset[] calldata assets, uint256 minReceivedAmount)
        external
        override
        returns (uint256 mintedGYDAmount)
    {
        DataTypes.MonetaryAmount[] memory vaultAmounts = _convertMintInputAssetsToVaultTokens(
            assets
        );
        DataTypes.ReserveState memory reserveState = gyroConfig
            .getReserveManager()
            .getReserveState();

        // TODO implement an interface and getGydRecovery() when interface is final.
        gyroConfig.getGydRecovery().checkAndRun(reserveState);

        DataTypes.Order memory order = _monetaryAmountsToMintOrder(
            vaultAmounts,
            reserveState.vaults
        );

        gyroConfig.getRootSafetyCheck().checkAndPersistMint(order);

        for (uint256 i = 0; i < vaultAmounts.length; i++) {
            DataTypes.MonetaryAmount memory vaultAmount = vaultAmounts[i];
            IERC20(vaultAmount.tokenAddress).safeTransfer(address(reserve), vaultAmount.amount);
        }

        DataTypes.Order memory orderAfterFees = gyroConfig.getFeeHandler().applyFees(order);

        uint256 usdValue = _getBasketUSDValue(orderAfterFees);
        mintedGYDAmount = pamm().mint(usdValue, reserveState.totalUSDValue);

        require(mintedGYDAmount >= minReceivedAmount, Errors.TOO_MUCH_SLIPPAGE);

        require(!_isOverCap(msg.sender, mintedGYDAmount), Errors.SUPPLY_CAP_EXCEEDED);

        gydToken.mint(msg.sender, mintedGYDAmount);
    }

    /// @inheritdoc IMotherboard
    function redeem(uint256 gydToRedeem, DataTypes.RedeemAsset[] calldata assets)
        external
        override
        returns (uint256[] memory)
    {
        DataTypes.ReserveState memory reserveState = gyroConfig
            .getReserveManager()
            .getReserveState();

        gyroConfig.getGydRecovery().checkAndRun(reserveState);

        gydToken.burnFrom(msg.sender, gydToRedeem);

        uint256 usdValueToRedeem = pamm().redeem(gydToRedeem, reserveState.totalUSDValue);
        require(
            usdValueToRedeem <= gydToRedeem.mulDown(FixedPoint.ONE + _REDEEM_DEVIATION_EPSILON),
            Errors.REDEEM_AMOUNT_BUG
        );

        DataTypes.Order memory order = _createRedeemOrder(
            usdValueToRedeem,
            assets,
            reserveState.vaults
        );
        gyroConfig.getRootSafetyCheck().checkAndPersistRedeem(order);

        DataTypes.Order memory orderAfterFees = gyroConfig.getFeeHandler().applyFees(order);
        return _convertAndSendRedeemOutputAssets(assets, orderAfterFees);
    }

    /// @inheritdoc IMotherboard
    function dryMint(
        DataTypes.MintAsset[] calldata assets,
        uint256 minReceivedAmount,
        address account
    ) external view override returns (uint256 mintedGYDAmount, string memory err) {
        DataTypes.MonetaryAmount[] memory vaultAmounts;
        (vaultAmounts, err) = _dryConvertMintInputAssetsToVaultTokens(assets);
        if (bytes(err).length > 0) {
            return (0, err);
        }

        DataTypes.ReserveState memory reserveState = gyroConfig
            .getReserveManager()
            .getReserveState();

        DataTypes.Order memory order = _monetaryAmountsToMintOrder(
            vaultAmounts,
            reserveState.vaults
        );

        err = gyroConfig.getRootSafetyCheck().isMintSafe(order);
        if (bytes(err).length > 0) {
            return (0, err);
        }

        DataTypes.Order memory orderAfterFees = gyroConfig.getFeeHandler().applyFees(order);
        uint256 usdValue = _getBasketUSDValue(orderAfterFees);
        mintedGYDAmount = pamm().computeMintAmount(usdValue, reserveState.totalUSDValue);

        if (mintedGYDAmount < minReceivedAmount) {
            return (mintedGYDAmount, Errors.TOO_MUCH_SLIPPAGE);
        }

        if (_isOverCap(account, mintedGYDAmount)) {
            return (mintedGYDAmount, Errors.SUPPLY_CAP_EXCEEDED);
        }
    }

    /// @inheritdoc IMotherboard
    function dryRedeem(uint256 gydToRedeem, DataTypes.RedeemAsset[] calldata assets)
        external
        view
        override
        returns (uint256[] memory outputAmounts, string memory err)
    {
        outputAmounts = new uint256[](assets.length);
        DataTypes.ReserveState memory reserveState = gyroConfig
            .getReserveManager()
            .getReserveState();
        uint256 usdValueToRedeem = pamm().computeRedeemAmount(
            gydToRedeem,
            reserveState.totalUSDValue
        );
        DataTypes.Order memory order = _createRedeemOrder(
            usdValueToRedeem,
            assets,
            reserveState.vaults
        );
        err = gyroConfig.getRootSafetyCheck().isRedeemSafe(order);
        if (bytes(err).length > 0) {
            return (outputAmounts, err);
        }
        DataTypes.Order memory orderAfterFees = gyroConfig.getFeeHandler().applyFees(order);
        return _computeRedeemOutputAmounts(assets, orderAfterFees);
    }

    function checkAndRunGydRecovery() external override returns (bool)
    {
        DataTypes.ReserveState memory reserveState = gyroConfig
            .getReserveManager()
            .getReserveState();
        return gyroConfig.getGydRecovery().checkAndRun(reserveState);
    }

    /// @inheritdoc IMotherboard
    function pamm() public view override returns (IPAMM) {
        return IPAMM(gyroConfig.getAddress(ConfigKeys.PAMM_ADDRESS));
    }

    function _dryConvertMintInputAssetsToVaultTokens(DataTypes.MintAsset[] calldata assets)
        internal
        view
        returns (DataTypes.MonetaryAmount[] memory vaultAmounts, string memory err)
    {
        vaultAmounts = new DataTypes.MonetaryAmount[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
            DataTypes.MintAsset calldata asset = assets[i];
            uint256 vaultTokenAmount;
            (vaultTokenAmount, err) = _computeVaultTokensForAsset(asset);
            if (bytes(err).length > 0) {
                return (vaultAmounts, err);
            }
            vaultAmounts[i] = DataTypes.MonetaryAmount({
                tokenAddress: asset.destinationVault,
                amount: vaultTokenAmount
            });
        }
    }

    function _computeVaultTokensForAsset(DataTypes.MintAsset calldata asset)
        internal
        view
        returns (uint256, string memory err)
    {
        if (asset.inputToken == asset.destinationVault) {
            return (asset.inputAmount, "");
        } else {
            IGyroVault vault = IGyroVault(asset.destinationVault);
            if (asset.inputToken == vault.underlying()) {
                return vault.dryDeposit(asset.inputAmount, 0);
            } else {
                return (0, Errors.INVALID_ASSET);
            }
        }
    }

    function _convertMintInputAssetsToVaultTokens(DataTypes.MintAsset[] calldata assets)
        internal
        returns (DataTypes.MonetaryAmount[] memory)
    {
        DataTypes.MonetaryAmount[] memory vaultAmounts = new DataTypes.MonetaryAmount[](
            assets.length
        );

        for (uint256 i = 0; i < assets.length; i++) {
            DataTypes.MintAsset calldata asset = assets[i];
            vaultAmounts[i] = DataTypes.MonetaryAmount({
                tokenAddress: asset.destinationVault,
                amount: _convertMintInputAssetToVaultToken(asset)
            });
        }
        return vaultAmounts;
    }

    function _convertMintInputAssetToVaultToken(DataTypes.MintAsset calldata asset)
        internal
        returns (uint256)
    {
        IGyroVault vault = IGyroVault(asset.destinationVault);

        IERC20(asset.inputToken).safeTransferFrom(msg.sender, address(this), asset.inputAmount);

        if (asset.inputToken == address(vault)) {
            return asset.inputAmount;
        }

        address lpTokenAddress = vault.underlying();
        require(asset.inputToken == lpTokenAddress, Errors.INVALID_ASSET);

        IERC20(lpTokenAddress).safeIncreaseAllowance(address(vault), asset.inputAmount);
        return vault.deposit(asset.inputAmount, 0);
    }

    function _getAssetAmountMint(address vault, DataTypes.MonetaryAmount[] memory amounts)
        internal
        pure
        returns (uint256)
    {
        uint256 total = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            DataTypes.MonetaryAmount memory vaultAmount = amounts[i];
            if (vaultAmount.tokenAddress == vault) total += vaultAmount.amount;
        }
        return total;
    }

    function _monetaryAmountsToMintOrder(
        DataTypes.MonetaryAmount[] memory amounts,
        DataTypes.VaultInfo[] memory vaultsInfo
    ) internal pure returns (DataTypes.Order memory) {
        DataTypes.Order memory order = DataTypes.Order({
            mint: true,
            vaultsWithAmount: new DataTypes.VaultWithAmount[](vaultsInfo.length)
        });

        for (uint256 i = 0; i < vaultsInfo.length; i++) {
            DataTypes.VaultInfo memory vaultInfo = vaultsInfo[i];
            order.vaultsWithAmount[i] = DataTypes.VaultWithAmount({
                amount: _getAssetAmountMint(vaultInfo.vault, amounts),
                vaultInfo: vaultInfo
            });
        }

        return order;
    }

    function _getRedeemAssetAmountAndRatio(
        DataTypes.VaultInfo memory vaultInfo,
        uint256 usdValueToRedeem,
        DataTypes.RedeemAsset[] calldata redeemAssets
    ) internal pure returns (uint256, uint256) {
        for (uint256 i = 0; i < redeemAssets.length; i++) {
            DataTypes.RedeemAsset calldata asset = redeemAssets[i];
            if (asset.originVault == vaultInfo.vault) {
                uint256 vaultUsdValueToWithdraw = usdValueToRedeem.mulDown(asset.valueRatio);
                uint256 vaultTokenAmount = vaultUsdValueToWithdraw.divDown(vaultInfo.price);
                uint256 scaledVaultTokenAmount = vaultTokenAmount.scaleTo(vaultInfo.decimals);

                return (scaledVaultTokenAmount, asset.valueRatio);
            }
        }
        return (0, 0);
    }

    function _createRedeemOrder(
        uint256 usdValueToRedeem,
        DataTypes.RedeemAsset[] calldata assets,
        DataTypes.VaultInfo[] memory vaultsInfo
    ) internal pure returns (DataTypes.Order memory) {
        _ensureNoDuplicates(assets);

        DataTypes.Order memory order = DataTypes.Order({
            mint: false,
            vaultsWithAmount: new DataTypes.VaultWithAmount[](vaultsInfo.length)
        });

        uint256 totalValueRatio = 0;

        for (uint256 i = 0; i < vaultsInfo.length; i++) {
            DataTypes.VaultInfo memory vaultInfo = vaultsInfo[i];
            (uint256 amount, uint256 valueRatio) = _getRedeemAssetAmountAndRatio(
                vaultInfo,
                usdValueToRedeem,
                assets
            );
            totalValueRatio += valueRatio;

            order.vaultsWithAmount[i] = DataTypes.VaultWithAmount({
                amount: amount,
                vaultInfo: vaultInfo
            });
        }

        require(totalValueRatio == FixedPoint.ONE, Errors.INVALID_ARGUMENT);

        return order;
    }

    function _convertAndSendRedeemOutputAssets(
        DataTypes.RedeemAsset[] calldata assets,
        DataTypes.Order memory order
    ) internal returns (uint256[] memory outputAmounts) {
        outputAmounts = new uint256[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
            DataTypes.RedeemAsset memory asset = assets[i];
            uint256 vaultTokenAmount = _getRedeemAmount(order.vaultsWithAmount, asset.originVault);
            uint256 outputAmount = _convertRedeemOutputAsset(asset, vaultTokenAmount);
            // ensure we received enough tokens and transfer them to the user
            require(outputAmount >= asset.minOutputAmount, Errors.TOO_MUCH_SLIPPAGE);
            outputAmounts[i] = outputAmount;

            IERC20(asset.outputToken).safeTransfer(msg.sender, outputAmount);
        }
    }

    function _getRedeemAmount(DataTypes.VaultWithAmount[] memory vaultsWithAmount, address vault)
        internal
        pure
        returns (uint256)
    {
        for (uint256 i = 0; i < vaultsWithAmount.length; i++) {
            DataTypes.VaultWithAmount memory vaultWithAmount = vaultsWithAmount[i];
            if (vaultWithAmount.vaultInfo.vault == vault) {
                return vaultWithAmount.amount;
            }
        }
        return 0;
    }

    function _convertRedeemOutputAsset(DataTypes.RedeemAsset memory asset, uint256 vaultTokenAmount)
        internal
        returns (uint256)
    {
        IGyroVault vault = IGyroVault(asset.originVault);
        // withdraw the amount of vault tokens from the reserve
        reserve.withdrawToken(address(vault), vaultTokenAmount);

        // nothing to do if the user wants the vault token
        if (asset.outputToken == address(vault)) {
            return vaultTokenAmount;
        } else {
            // otherwise, convert the vault token into its underlying LP token
            require(asset.outputToken == vault.underlying(), Errors.INVALID_ASSET);
            return vault.withdraw(vaultTokenAmount, 0);
        }
    }

    function _computeRedeemOutputAmounts(
        DataTypes.RedeemAsset[] calldata assets,
        DataTypes.Order memory order
    ) internal view returns (uint256[] memory outputAmounts, string memory err) {
        outputAmounts = new uint256[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
            DataTypes.RedeemAsset calldata asset = assets[i];
            uint256 vaultTokenAmount = _getRedeemAmount(order.vaultsWithAmount, asset.originVault);
            uint256 outputAmount;
            (outputAmount, err) = _computeRedeemOutputAmount(asset, vaultTokenAmount);
            if (bytes(err).length > 0) {
                return (outputAmounts, err);
            }
            // ensure we received enough tokens and transfer them to the user
            if (outputAmount < asset.minOutputAmount) {
                return (outputAmounts, Errors.TOO_MUCH_SLIPPAGE);
            }
            outputAmounts[i] = outputAmount;
        }
    }

    function _computeRedeemOutputAmount(
        DataTypes.RedeemAsset calldata asset,
        uint256 vaultTokenAmount
    ) internal view returns (uint256 outputAmount, string memory err) {
        IGyroVault vault = IGyroVault(asset.originVault);

        // nothing to do if the user wants the vault token
        if (asset.outputToken == address(vault)) {
            return (vaultTokenAmount, "");
        }

        // otherwise, we need the outputToken to be the underlying LP token
        // and to convert the vault token into the underlying LP token
        if (asset.outputToken != vault.underlying()) {
            return (0, Errors.INVALID_ASSET);
        }

        uint256 vaultTokenBalance = vault.balanceOf(address(reserve));
        if (vaultTokenBalance < vaultTokenAmount) {
            return (0, Errors.INSUFFICIENT_BALANCE);
        }

        return vault.dryWithdraw(vaultTokenAmount, 0);
    }

    function _getBasketUSDValue(DataTypes.Order memory order)
        internal
        pure
        returns (uint256 result)
    {
        for (uint256 i = 0; i < order.vaultsWithAmount.length; i++) {
            DataTypes.VaultWithAmount memory vaultWithAmount = order.vaultsWithAmount[i];
            uint256 scaledAmount = vaultWithAmount.amount.scaleFrom(
                vaultWithAmount.vaultInfo.decimals
            );
            result += scaledAmount.mulDown(vaultWithAmount.vaultInfo.price);
        }
    }

    function _isOverCap(address account, uint256 mintedGYDAmount) internal view returns (bool) {
        uint256 globalSupplyCap = gyroConfig.getGlobalSupplyCap();
        if (gydToken.totalSupply() + mintedGYDAmount > globalSupplyCap) {
            return true;
        }
        bool isAuthenticated = gyroConfig.isAuthenticated(account);
        uint256 perUserSupplyCap = gyroConfig.getPerUserSupplyCap(isAuthenticated);
        return gydToken.balanceOf(account) + mintedGYDAmount > perUserSupplyCap;
    }

    function _ensureNoDuplicates(DataTypes.RedeemAsset[] calldata redeemAssets) internal pure {
        for (uint256 i = 0; i < redeemAssets.length; i++) {
            DataTypes.RedeemAsset calldata asset = redeemAssets[i];
            for (uint256 j = i + 1; j < redeemAssets.length; j++) {
                DataTypes.RedeemAsset calldata otherAsset = redeemAssets[j];
                require(asset.originVault != otherAsset.originVault, Errors.INVALID_ARGUMENT);
            }
        }
    }
}
