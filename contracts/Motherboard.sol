// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IFeeHandler.sol";
import "../interfaces/IMotherBoard.sol";
import "../interfaces/IGyroVault.sol";
import "../interfaces/ILPTokenExchangerRegistry.sol";
import "../interfaces/ILPTokenExchanger.sol";
import "../interfaces/IPAMM.sol";
import "../interfaces/IGyroConfig.sol";
import "../interfaces/IGYDToken.sol";
import "../interfaces/IFeeBank.sol";
import "../interfaces/oracles/IUSDPriceOracle.sol";

import "../libraries/DataTypes.sol";
import "../libraries/ConfigKeys.sol";
import "../libraries/ConfigHelpers.sol";
import "../libraries/Errors.sol";
import "../libraries/FixedPoint.sol";
import "../libraries/DecimalScale.sol";
import "../libraries/AssetPricer.sol";

import "./auth/Governable.sol";

/// @title MotherBoard is the central contract connecting the different pieces
/// of the Gyro protocol
contract Motherboard is IMotherBoard, Governable {
    using FixedPoint for uint256;
    using DecimalScale for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IGYDToken;
    using ConfigHelpers for IGyroConfig;
    using AssetPricer for IUSDPriceOracle;

    /// @inheritdoc IMotherBoard
    IGYDToken public immutable override gydToken;

    /// @inheritdoc IMotherBoard
    IReserve public immutable override reserve;

    /// @inheritdoc IMotherBoard
    IGyroConfig public immutable override gyroConfig;

    constructor(IGyroConfig _gyroConfig) {
        gyroConfig = _gyroConfig;
        gydToken = _gyroConfig.getGYDToken();
        reserve = _gyroConfig.getReserve();
        gydToken.safeApprove(address(_gyroConfig.getFeeBank()), type(uint256).max);
    }

    /// @inheritdoc IMotherBoard
    function mint(DataTypes.MintAsset[] calldata assets, uint256 minReceivedAmount)
        external
        override
        returns (uint256 mintedGYDAmount)
    {
        DataTypes.MonetaryAmount[] memory vaultAmounts = _convertMintInputAssetsToVaultTokens(
            assets
        );
        DataTypes.VaultInfo[] memory vaultsInfo = gyroConfig.getVaultManager().listVaults();
        DataTypes.Order memory order = _monetaryAmountsToMintOrder(vaultAmounts, vaultsInfo);

        gyroConfig.getRootSafetyCheck().checkAndPersistMint(order);

        for (uint256 i = 0; i < assets.length; i++) {
            DataTypes.MonetaryAmount memory vaultAmount = vaultAmounts[i];
            IERC20(vaultAmount.tokenAddress).safeTransfer(address(reserve), vaultAmount.amount);
        }

        DataTypes.Order memory orderAfterFees = gyroConfig.getFeeHandler().applyFees(order);

        uint256 usdValue = gyroConfig.getRootPriceOracle().getBasketUSDValue(
            orderAfterFees.vaultsWithAmount
        );
        uint256 gyroToMint = pamm().mint(usdValue);

        require(gyroToMint >= minReceivedAmount, Errors.TOO_MUCH_SLIPPAGE);

        gydToken.mint(address(this), gyroToMint);

        gydToken.safeTransfer(msg.sender, gyroToMint);

        return gyroToMint;
    }

    /// @inheritdoc IMotherBoard
    function redeem(uint256 gydToRedeem, DataTypes.RedeemAsset[] calldata assets)
        external
        override
        returns (uint256[] memory)
    {
        gydToken.burnFrom(msg.sender, gydToRedeem);
        uint256 usdValueToRedeem = pamm().redeem(gydToRedeem);
        DataTypes.Order memory order = _createRedeemOrder(usdValueToRedeem, assets);
        gyroConfig.getRootSafetyCheck().checkAndPersistRedeem(order);
        DataTypes.Order memory orderAfterFees = gyroConfig.getFeeHandler().applyFees(order);
        return _convertAndSendRedeemOutputAssets(assets, orderAfterFees);
    }

    /// @inheritdoc IMotherBoard
    function dryMint(DataTypes.MintAsset[] calldata assets, uint256 minReceivedAmount)
        external
        view
        override
        returns (uint256 mintedGYDAmount, string memory err)
    {
        DataTypes.MonetaryAmount[] memory vaultAmounts;
        (vaultAmounts, err) = _dryConvertMintInputAssetsToVaultTokens(assets);
        if (bytes(err).length > 0) {
            return (0, err);
        }

        DataTypes.VaultInfo[] memory vaultsInfo = gyroConfig.getVaultManager().listVaults();
        DataTypes.Order memory order = _monetaryAmountsToMintOrder(vaultAmounts, vaultsInfo);
        err = gyroConfig.getRootSafetyCheck().isMintSafe(order);

        DataTypes.Order memory orderAfterFees = gyroConfig.getFeeHandler().applyFees(order);

        uint256 usdValue = gyroConfig.getRootPriceOracle().getBasketUSDValue(
            orderAfterFees.vaultsWithAmount
        );
        mintedGYDAmount = pamm().computeMintAmount(usdValue);

        if (mintedGYDAmount < minReceivedAmount) {
            err = Errors.TOO_MUCH_SLIPPAGE;
        }
    }

    /// @inheritdoc IMotherBoard
    function dryRedeem(uint256 gydToRedeem, DataTypes.RedeemAsset[] calldata assets)
        external
        view
        override
        returns (uint256[] memory outputAmounts, string memory err)
    {
        outputAmounts = new uint256[](assets.length);

        uint256 usdValueToRedeem = pamm().computeRedeemAmount(gydToRedeem);
        DataTypes.Order memory order = _createRedeemOrder(usdValueToRedeem, assets);
        err = gyroConfig.getRootSafetyCheck().isRedeemSafe(order);
        if (bytes(err).length > 0) {
            return (outputAmounts, err);
        }
        DataTypes.Order memory orderAfterFees = gyroConfig.getFeeHandler().applyFees(order);
        return _computeRedeemOutputAmounts(assets, orderAfterFees);
    }

    /// @inheritdoc IMotherBoard
    function pamm() public view override returns (IPAMM) {
        return IPAMM(gyroConfig.getAddress(ConfigKeys.PAMM_ADDRESS));
    }

    function _dryConvertMintInputAssetsToVaultTokens(DataTypes.MintAsset[] calldata assets)
        internal
        view
        returns (DataTypes.MonetaryAmount[] memory vaultAmounts, string memory err)
    {
        vaultAmounts = new DataTypes.MonetaryAmount[](assets.length);
        ILPTokenExchangerRegistry exchangerRegistry = gyroConfig.getExchangerRegistry();
        for (uint256 i = 0; i < assets.length; i++) {
            DataTypes.MintAsset calldata asset = assets[i];
            uint256 vaultTokenAmount;
            (vaultTokenAmount, err) = _computeVaultTokensForAsset(asset, exchangerRegistry);
            if (bytes(err).length > 0) {
                return (vaultAmounts, err);
            }
            vaultAmounts[i] = DataTypes.MonetaryAmount({
                tokenAddress: asset.destinationVault,
                amount: vaultTokenAmount
            });
        }
    }

    function _computeVaultTokensForAsset(
        DataTypes.MintAsset calldata asset,
        ILPTokenExchangerRegistry exchangerRegistry
    ) internal view returns (uint256, string memory err) {
        if (asset.inputToken == asset.destinationVault) {
            return (asset.inputAmount, "");
        } else {
            IGyroVault vault = IGyroVault(asset.destinationVault);
            address lpTokenAddress = vault.underlying();
            uint256 lpTokenAmount;
            if (asset.inputToken == lpTokenAddress) {
                lpTokenAmount = asset.inputAmount;
            } else {
                ILPTokenExchanger exchanger = exchangerRegistry.getTokenExchanger(lpTokenAddress);
                (lpTokenAmount, err) = exchanger.dryDeposit(
                    DataTypes.MonetaryAmount(asset.inputToken, asset.inputAmount)
                );
                if (bytes(err).length > 0) {
                    return (0, err);
                }
            }

            return vault.dryDeposit(lpTokenAmount, 0);
        }
    }

    function _convertMintInputAssetsToVaultTokens(DataTypes.MintAsset[] calldata assets)
        internal
        returns (DataTypes.MonetaryAmount[] memory)
    {
        DataTypes.MonetaryAmount[] memory vaultAmounts = new DataTypes.MonetaryAmount[](
            assets.length
        );

        ILPTokenExchangerRegistry exchangerRegistry = gyroConfig.getExchangerRegistry();
        for (uint256 i = 0; i < assets.length; i++) {
            DataTypes.MintAsset calldata asset = assets[i];
            vaultAmounts[i] = DataTypes.MonetaryAmount({
                tokenAddress: asset.destinationVault,
                amount: _convertMintInputAssetToVaultToken(asset, exchangerRegistry)
            });
        }
        return vaultAmounts;
    }

    function _convertMintInputAssetToVaultToken(
        DataTypes.MintAsset calldata asset,
        ILPTokenExchangerRegistry exchangerRegistry
    ) internal returns (uint256) {
        IGyroVault vault = IGyroVault(asset.destinationVault);

        IERC20(asset.inputToken).safeTransferFrom(msg.sender, address(this), asset.inputAmount);

        if (asset.inputToken == address(vault)) {
            return asset.inputAmount;
        }

        uint256 lpTokenAmount;
        address lpTokenAddress = vault.underlying();
        if (asset.inputToken == lpTokenAddress) {
            lpTokenAmount = asset.inputAmount;
        } else {
            ILPTokenExchanger exchanger = exchangerRegistry.getTokenExchanger(lpTokenAddress);
            lpTokenAmount = exchanger.deposit(
                DataTypes.MonetaryAmount(asset.inputToken, asset.inputAmount)
            );
        }

        IERC20(lpTokenAddress).safeApprove(address(vault), lpTokenAmount);
        return vault.deposit(lpTokenAmount, 0);
    }

    function _getVaultInfo(address vaultAddress, DataTypes.VaultInfo[] memory vaultInfo)
        internal
        pure
        returns (DataTypes.VaultInfo memory)
    {
        uint256 length = vaultInfo.length;
        for (uint256 i = 0; i < length; i++) {
            DataTypes.VaultInfo memory info = vaultInfo[i];
            if (info.vault == vaultAddress) {
                return info;
            }
        }
        revert(Errors.INVALID_ARGUMENT);
    }

    function _monetaryAmountsToMintOrder(
        DataTypes.MonetaryAmount[] memory amounts,
        DataTypes.VaultInfo[] memory vaultsInfo
    ) internal pure returns (DataTypes.Order memory) {
        DataTypes.Order memory order = DataTypes.Order({
            mint: true,
            vaultsWithAmount: new DataTypes.VaultWithAmount[](amounts.length)
        });

        for (uint256 i = 0; i < amounts.length; i++) {
            DataTypes.MonetaryAmount memory vaultAmount = amounts[i];
            order.vaultsWithAmount[i] = DataTypes.VaultWithAmount({
                amount: vaultAmount.amount,
                vaultInfo: _getVaultInfo(vaultAmount.tokenAddress, vaultsInfo)
            });
        }
        return order;
    }

    function _createRedeemOrder(uint256 usdValueToRedeem, DataTypes.RedeemAsset[] calldata assets)
        internal
        view
        returns (DataTypes.Order memory)
    {
        IUSDPriceOracle priceOracle = gyroConfig.getRootPriceOracle();

        DataTypes.Order memory order = DataTypes.Order({
            mint: false,
            vaultsWithAmount: new DataTypes.VaultWithAmount[](assets.length)
        });

        DataTypes.VaultInfo[] memory vaultsInfo = gyroConfig.getVaultManager().listVaults();
        uint256 totalValueRatio = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            DataTypes.RedeemAsset memory asset = assets[i];
            totalValueRatio += asset.valueRatio;
            IGyroVault vault = IGyroVault(asset.originVault);
            uint256 vaultUsdValueToWithdraw = usdValueToRedeem.mulDown(asset.valueRatio);
            uint256 vaultTokenPrice = priceOracle.getPriceUSD(address(vault));

            uint256 vaultTokenAmount = vaultUsdValueToWithdraw.divDown(vaultTokenPrice);
            uint256 scaledVaultTokenAmount = vaultTokenAmount.scaleTo(vault.decimals());
            order.vaultsWithAmount[i] = DataTypes.VaultWithAmount({
                amount: scaledVaultTokenAmount,
                vaultInfo: _getVaultInfo(asset.originVault, vaultsInfo)
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
        ILPTokenExchangerRegistry exchangerRegistry = gyroConfig.getExchangerRegistry();
        for (uint256 i = 0; i < assets.length; i++) {
            DataTypes.RedeemAsset memory asset = assets[i];
            uint256 vaultTokenAmount = order.vaultsWithAmount[i].amount;
            uint256 outputAmount = _convertRedeemOutputAsset(
                asset,
                vaultTokenAmount,
                exchangerRegistry
            );
            // ensure we received enough tokens and transfer them to the user
            require(outputAmount >= asset.minOutputAmount, Errors.TOO_MUCH_SLIPPAGE);
            outputAmounts[i] = outputAmount;

            IERC20(asset.outputToken).safeTransfer(msg.sender, outputAmount);
        }
    }

    function _convertRedeemOutputAsset(
        DataTypes.RedeemAsset memory asset,
        uint256 vaultTokenAmount,
        ILPTokenExchangerRegistry exchangerRegistry
    ) internal returns (uint256) {
        IGyroVault vault = IGyroVault(asset.originVault);
        // withdraw the amount of vault tokens from the reserve
        reserve.withdrawToken(address(vault), vaultTokenAmount);

        // nothing to do if the user wants the vault token
        if (asset.outputToken == address(vault)) {
            return vaultTokenAmount;
        } else {
            // convert the vault token into its underlying LP token
            uint256 lpTokenAmount = vault.withdraw(vaultTokenAmount, 0);

            address lpTokenAddress = vault.underlying();
            // nothing more to do if the user wants the underlying LP token
            if (asset.outputToken == lpTokenAddress) {
                return lpTokenAmount;
            } else {
                // otherwise, convert the LP token into the desired output token
                ILPTokenExchanger exchanger = exchangerRegistry.getTokenExchanger(lpTokenAddress);
                return
                    exchanger.withdraw(DataTypes.MonetaryAmount(asset.outputToken, lpTokenAmount));
            }
        }
    }

    function _computeRedeemOutputAmounts(
        DataTypes.RedeemAsset[] calldata assets,
        DataTypes.Order memory order
    ) internal view returns (uint256[] memory outputAmounts, string memory err) {
        outputAmounts = new uint256[](assets.length);
        ILPTokenExchangerRegistry exchangerRegistry = gyroConfig.getExchangerRegistry();
        for (uint256 i = 0; i < assets.length; i++) {
            DataTypes.RedeemAsset calldata asset = assets[i];
            uint256 vaultTokenAmount = order.vaultsWithAmount[i].amount;
            uint256 outputAmount;
            (outputAmount, err) = _computeRedeemOutputAmount(
                asset,
                vaultTokenAmount,
                exchangerRegistry
            );
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
        uint256 vaultTokenAmount,
        ILPTokenExchangerRegistry exchangerRegistry
    ) internal view returns (uint256 outputAmount, string memory err) {
        IGyroVault vault = IGyroVault(asset.originVault);

        // nothing to do if the user wants the vault token
        if (asset.outputToken == address(vault)) {
            return (vaultTokenAmount, "");
        } else {
            // convert the vault token into its underlying LP token
            uint256 lpTokenAmount;
            (lpTokenAmount, err) = vault.dryWithdraw(vaultTokenAmount, 0);
            if (bytes(err).length > 0) {
                return (0, err);
            }

            address lpTokenAddress = vault.underlying();
            // nothing more to do if the user wants the underlying LP token
            if (asset.outputToken == lpTokenAddress) {
                return (lpTokenAmount, "");
            } else {
                // otherwise, convert the LP token into the desired output token
                ILPTokenExchanger exchanger = exchangerRegistry.getTokenExchanger(lpTokenAddress);
                return
                    exchanger.dryWithdraw(
                        DataTypes.MonetaryAmount(asset.outputToken, lpTokenAmount)
                    );
            }
        }
    }
}
