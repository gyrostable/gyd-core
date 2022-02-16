// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IMotherBoard.sol";
import "../interfaces/IGyroVault.sol";
import "../interfaces/ILPTokenExchangerRegistry.sol";
import "../interfaces/ILPTokenExchanger.sol";
import "../interfaces/IPAMM.sol";
import "../interfaces/IGyroConfig.sol";
import "../interfaces/IGYDToken.sol";
import "../interfaces/IFeeBank.sol";
import "../interfaces/IAssetPricer.sol";
import "../interfaces/oracles/IUSDPriceOracle.sol";

import "../libraries/DataTypes.sol";
import "../libraries/ConfigKeys.sol";
import "../libraries/ConfigHelpers.sol";
import "../libraries/Errors.sol";
import "../libraries/FixedPoint.sol";

import "./auth/Governable.sol";

/// @title MotherBoard is the central contract connecting the different pieces
/// of the Gyro protocol
contract Motherboard is IMotherBoard, Governable {
    using FixedPoint for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IGYDToken;
    using ConfigHelpers for IGyroConfig;

    /// @inheritdoc IMotherBoard
    IGYDToken public immutable override gydToken;

    /// @inheritdoc IMotherBoard
    IReserve public immutable override reserve;

    /// @inheritdoc IMotherBoard
    IGyroConfig public immutable override gyroConfig;

    constructor(IGyroConfig _gyroConfig) {
        gyroConfig = _gyroConfig;
        gydToken = IGYDToken(_gyroConfig.getAddress(ConfigKeys.GYD_TOKEN_ADDRESS));
        reserve = IReserve(_gyroConfig.getAddress(ConfigKeys.RESERVE_ADDRESS));
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
        ISafetyCheck.Order memory order = _monetaryAmountsToOrder(vaultAmounts, vaultsInfo);

        gyroConfig.getRootSafetyCheck().checkAndPersistMint(order);

        for (uint256 i = 0; i < assets.length; i++) {
            DataTypes.MonetaryAmount memory vaultAmount = vaultAmounts[i];
            IERC20(vaultAmount.tokenAddress).safeTransfer(address(reserve), vaultAmount.amount);
        }

        uint256 mintFeeFraction = gyroConfig.getUint(ConfigKeys.MINT_FEE);
        uint256 usdValue = gyroConfig.getAssetPricer().getBasketUSDValue(vaultAmounts);
        uint256 gyroToMint = pamm().mint(usdValue);

        uint256 feeToPay = gyroToMint.mulUp(mintFeeFraction);

        uint256 remainingGyro = gyroToMint - feeToPay;

        require(remainingGyro >= minReceivedAmount, Errors.TOO_MUCH_SLIPPAGE);

        gydToken.mint(gyroToMint);
        gyroConfig.getFeeBank().depositFees(address(gydToken), feeToPay);

        gydToken.safeTransfer(msg.sender, remainingGyro);

        return gyroToMint;
    }

    /// @inheritdoc IMotherBoard
    function redeem(uint256 gydToRedeem, DataTypes.RedeemAsset[] calldata assets)
        external
        override
        returns (uint256[] memory)
    {
        gydToken.burnFor(gydToRedeem, msg.sender);

        uint256 usdValueToRedeem = pamm().redeem(gydToRedeem);

        IUSDPriceOracle priceOracle = gyroConfig.getRootPriceOracle();

        ISafetyCheck.Order memory order = ISafetyCheck.Order({
            mint: false,
            vaultsWithAmount: new ISafetyCheck.VaultWithAmount[](assets.length)
        });

        uint256 totalValueRatio = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            DataTypes.RedeemAsset memory asset = assets[i];
            totalValueRatio += asset.valueRatio;
            IGyroVault vault = IGyroVault(asset.originVault);
            uint256 vaultUsdValueToWithdraw = usdValueToRedeem.mulDown(asset.valueRatio);
            uint256 vaultTokenPrice = priceOracle.getPriceUSD(address(vault));

            uint256 vaultTokenAmount = vaultUsdValueToWithdraw.divDown(vaultTokenPrice);
            order.vaultsWithAmount[i] = ISafetyCheck.VaultWithAmount({
                amount: vaultTokenAmount,
                vaultInfo: _getVaultInfo(
                    asset.originVault,
                    gyroConfig.getVaultManager().listVaults()
                )
            });
        }

        require(totalValueRatio == FixedPoint.ONE, Errors.INVALID_ARGUMENT);

        gyroConfig.getRootSafetyCheck().checkAndPersistRedeem(order);

        return _convertAndSendRedeemOutputAssets(assets, order);
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
        ISafetyCheck.Order memory order = _monetaryAmountsToOrder(vaultAmounts, vaultsInfo);
        err = gyroConfig.getRootSafetyCheck().isMintSafe(order);

        uint256 mintFeeFraction = gyroConfig.getUint(ConfigKeys.MINT_FEE);
        uint256 usdValue = gyroConfig.getAssetPricer().getBasketUSDValue(vaultAmounts);
        mintedGYDAmount = pamm().computeMintAmount(usdValue);

        uint256 feeToPay = mintedGYDAmount.mulUp(mintFeeFraction);

        uint256 remainingGyro = mintedGYDAmount - feeToPay;

        if (remainingGyro < minReceivedAmount) {
            err = Errors.TOO_MUCH_SLIPPAGE;
        }
    }

    /// @inheritdoc IMotherBoard
    function dryRedeem(uint256 gydToRedeem, DataTypes.RedeemAsset[] memory assets)
        external
        view
        override
        returns (uint256[] memory outputAmounts, string memory err)
    {
        outputAmounts = new uint256[](assets.length);

        uint256 usdValueToRedeem = pamm().computeRedeemAmount(gydToRedeem);

        IUSDPriceOracle priceOracle = IUSDPriceOracle(
            gyroConfig.getAddress(ConfigKeys.ROOT_PRICE_ORACLE_ADDRESS)
        );

        // for (uint256 i = 0; i < assets.length; i++) {
        //     DataTypes.RedeemAsset memory asset = assets[i];
        //     IGyroVault vault = IGyroVault(asset.originVault);
        //     uint256 vaultUsdValueToWithdraw = usdValueToRedeem.mulDown(asset.valueRatio);
        //     uint256 vaultTokenPrice = priceOracle.getPriceUSD(address(vault));

        //     uint256 vaultTokenAmount = vaultUsdValueToWithdraw.divDown(vaultTokenPrice);

        //     // withdraw the amount of vault tokens from the reserve
        //     reserve.withdrawToken(address(vault), vaultTokenAmount);

        //     uint256 outputAmount;

        //     // nothing to do if the user wants the vault token
        //     if (asset.outputToken == address(vault)) {
        //         outputAmount = vaultTokenAmount;
        //     } else {
        //         // convert the vault token into its underlying LP token
        //         uint256 lpTokenAmount = vault.withdraw(vaultTokenAmount);

        //         address lpTokenAddress = vault.lpToken();
        //         // nothing more to do if the user wants the underlying LP token
        //         if (asset.outputToken == lpTokenAddress) {
        //             outputAmount = lpTokenAmount;
        //         } else {
        //             // otherwise, convert the LP token into the desired output token
        //             ILPTokenExchanger exchanger = exchangerRegistry.getTokenExchanger(
        //                 lpTokenAddress
        //             );
        //             lpTokenAmount = exchanger.withdraw(
        //                 DataTypes.MonetaryAmount(asset.outputToken, outputAmount)
        //             );
        //         }
        //     }

        //     // ensure we received enough tokens and transfer them to the user
        //     require(outputAmount >= asset.minOutputAmount, Errors.TOO_MUCH_SLIPPAGE);
        //     outputAmounts[i] = outputAmount;

        //     IERC20(asset.outputToken).safeTransfer(msg.sender, outputAmount);
        // }
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
            DataTypes.MintAsset memory asset = assets[i];

            uint256 vaultTokenAmount;

            if (asset.inputToken == asset.destinationVault) {
                vaultTokenAmount = asset.inputAmount;
            } else {
                IGyroVault vault = IGyroVault(asset.destinationVault);
                address lpTokenAddress = vault.lpToken();
                uint256 lpTokenAmount;
                if (asset.inputToken == lpTokenAddress) {
                    lpTokenAmount = asset.inputAmount;
                } else {
                    ILPTokenExchanger exchanger = exchangerRegistry.getTokenExchanger(
                        lpTokenAddress
                    );
                    (lpTokenAmount, err) = exchanger.dryDeposit(
                        DataTypes.MonetaryAmount(asset.inputToken, asset.inputAmount)
                    );
                    if (bytes(err).length > 0) {
                        break;
                    }
                }

                (vaultTokenAmount, err) = vault.dryDepositFor(address(reserve), lpTokenAmount);
                if (bytes(err).length > 0) {
                    break;
                }
            }

            vaultAmounts[i] = DataTypes.MonetaryAmount({
                tokenAddress: asset.destinationVault,
                amount: vaultTokenAmount
            });
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

            IGyroVault vault = IGyroVault(asset.destinationVault);

            IERC20(asset.inputToken).safeTransferFrom(msg.sender, address(this), asset.inputAmount);

            uint256 vaultTokenAmount;
            if (asset.inputToken == address(vault)) {
                vaultTokenAmount = asset.inputAmount;
            } else {
                uint256 lpTokenAmount;
                address lpTokenAddress = vault.lpToken();
                if (asset.inputToken == lpTokenAddress) {
                    lpTokenAmount = asset.inputAmount;
                } else {
                    ILPTokenExchanger exchanger = exchangerRegistry.getTokenExchanger(
                        lpTokenAddress
                    );
                    lpTokenAmount = exchanger.deposit(
                        DataTypes.MonetaryAmount(asset.inputToken, asset.inputAmount)
                    );
                }
                vaultTokenAmount = vault.deposit(lpTokenAmount);
            }

            vaultAmounts[i] = DataTypes.MonetaryAmount({
                tokenAddress: asset.destinationVault,
                amount: vaultTokenAmount
            });
        }
        return vaultAmounts;
    }

    function _convertAndSendRedeemOutputAssets(
        DataTypes.RedeemAsset[] calldata assets,
        ISafetyCheck.Order memory order
    ) internal returns (uint256[] memory outputAmounts) {
        outputAmounts = new uint256[](assets.length);
        ILPTokenExchangerRegistry exchangerRegistry = gyroConfig.getExchangerRegistry();
        for (uint256 i = 0; i < assets.length; i++) {
            DataTypes.RedeemAsset memory asset = assets[i];
            IGyroVault vault = IGyroVault(asset.originVault);
            uint256 vaultTokenAmount = order.vaultsWithAmount[i].amount;
            // withdraw the amount of vault tokens from the reserve
            reserve.withdrawToken(address(vault), vaultTokenAmount);

            uint256 outputAmount;

            // nothing to do if the user wants the vault token
            if (asset.outputToken == address(vault)) {
                outputAmount = vaultTokenAmount;
            } else {
                // convert the vault token into its underlying LP token
                uint256 lpTokenAmount = vault.withdraw(vaultTokenAmount);

                address lpTokenAddress = vault.lpToken();
                // nothing more to do if the user wants the underlying LP token
                if (asset.outputToken == lpTokenAddress) {
                    outputAmount = lpTokenAmount;
                } else {
                    // otherwise, convert the LP token into the desired output token
                    ILPTokenExchanger exchanger = exchangerRegistry.getTokenExchanger(
                        lpTokenAddress
                    );
                    outputAmount = exchanger.withdraw(
                        DataTypes.MonetaryAmount(asset.outputToken, lpTokenAmount)
                    );
                }
            }

            // ensure we received enough tokens and transfer them to the user
            require(outputAmount >= asset.minOutputAmount, Errors.TOO_MUCH_SLIPPAGE);
            outputAmounts[i] = outputAmount;

            IERC20(asset.outputToken).safeTransfer(msg.sender, outputAmount);
        }
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

    function _monetaryAmountsToOrder(
        DataTypes.MonetaryAmount[] memory amounts,
        DataTypes.VaultInfo[] memory vaultsInfo
    ) internal pure returns (ISafetyCheck.Order memory) {
        ISafetyCheck.Order memory order = ISafetyCheck.Order({
            mint: true,
            vaultsWithAmount: new ISafetyCheck.VaultWithAmount[](amounts.length)
        });

        for (uint256 i = 0; i < amounts.length; i++) {
            DataTypes.MonetaryAmount memory vaultAmount = amounts[i];
            order.vaultsWithAmount[i] = ISafetyCheck.VaultWithAmount({
                amount: vaultAmount.amount,
                vaultInfo: _getVaultInfo(vaultAmount.tokenAddress, vaultsInfo)
            });
        }
        return order;
    }
}
