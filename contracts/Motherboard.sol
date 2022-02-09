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

    // NOTE: dryMint and dryRedeem should be calling the safety check functions to ensure that the Reserve will remain stable.

    /// @inheritdoc IMotherBoard
    IGYDToken public immutable override gydToken;

    /// @inheritdoc IMotherBoard
    IReserve public immutable override reserve;

    /// @inheritdoc IMotherBoard
    IGyroConfig public immutable override gyroConfig;

    /// @inheritdoc IMotherBoard
    ILPTokenExchangerRegistry public override exchangerRegistry;

    /// @inheritdoc IMotherBoard
    IFeeBank public override feeBank;

    /// @inheritdoc IMotherBoard
    IAssetPricer public override assetPricer;

    constructor(IGyroConfig _gyroConfig) {
        gyroConfig = _gyroConfig;
        gydToken = IGYDToken(_gyroConfig.getAddress(ConfigKeys.GYD_TOKEN_ADDRESS));
        exchangerRegistry = ILPTokenExchangerRegistry(
            _gyroConfig.getAddress(ConfigKeys.EXCHANGER_REGISTRY_ADDRESS)
        );
        reserve = IReserve(_gyroConfig.getAddress(ConfigKeys.RESERVE_ADDRESS));
        assetPricer = IAssetPricer(_gyroConfig.getAddress(ConfigKeys.ASSET_PRICER_ADDRESS));
        address feeBankAddress = _gyroConfig.getAddress(ConfigKeys.FEE_BANK_ADDRESS);
        feeBank = IFeeBank(feeBankAddress);
        gydToken.safeApprove(feeBankAddress, type(uint256).max);
    }

    /// @inheritdoc IMotherBoard
    function mint(DataTypes.MintAsset[] calldata assets, uint256 minReceivedAmount)
        external
        override
        returns (uint256 mintedGYDAmount)
    {
        DataTypes.MonetaryAmount[] memory vaultAmounts = new DataTypes.MonetaryAmount[](
            assets.length
        );

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
                vaultTokenAmount = vault.depositFor(address(reserve), lpTokenAmount);
            }

            vaultAmounts[i] = DataTypes.MonetaryAmount({
                tokenAddress: asset.destinationVault,
                amount: vaultTokenAmount
            });
        }

        uint256 mintFeeFraction = gyroConfig.getUint(ConfigKeys.MINT_FEE);
        uint256 usdValue = assetPricer.getBasketUSDValue(vaultAmounts);
        uint256 gyroToMint = pamm().mint(usdValue);

        uint256 feeToPay = gyroToMint.mulUp(mintFeeFraction);

        uint256 remainingGyro = gyroToMint - feeToPay;

        require(remainingGyro >= minReceivedAmount, Errors.TOO_MUCH_SLIPPAGE);

        gydToken.mint(gyroToMint);
        feeBank.depositFees(address(gydToken), feeToPay);

        gydToken.safeTransfer(msg.sender, remainingGyro);

        return gyroToMint;
    }

    /// @inheritdoc IMotherBoard
    function redeem(uint256 gydToRedeem, DataTypes.RedeemAsset[] calldata assets)
        external
        override
        returns (uint256[] memory outputAmounts)
    {
        gydToken.burnFor(gydToRedeem, msg.sender);

        outputAmounts = new uint256[](assets.length);

        uint256 usdValueToRedeem = pamm().redeem(gydToRedeem);

        IUSDPriceOracle priceOracle = gyroConfig.getRootPriceOracle();

        uint256 totalValueRatio = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            DataTypes.RedeemAsset memory asset = assets[i];
            totalValueRatio += asset.valueRatio;
            IGyroVault vault = IGyroVault(asset.originVault);
            uint256 vaultUsdValueToWithdraw = usdValueToRedeem.mulDown(asset.valueRatio);
            uint256 vaultTokenPrice = priceOracle.getPriceUSD(address(vault));

            uint256 vaultTokenAmount = vaultUsdValueToWithdraw.divDown(vaultTokenPrice);

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

        require(totalValueRatio == FixedPoint.ONE, Errors.INVALID_ARGUMENT);
    }

    /// @inheritdoc IMotherBoard
    function dryMint(DataTypes.MintAsset[] calldata assets, uint256 minReceivedAmount)
        external
        view
        override
        returns (uint256 mintedGYDAmount, string memory err)
    {
        DataTypes.MonetaryAmount[] memory vaultAmounts = new DataTypes.MonetaryAmount[](
            assets.length
        );

        for (uint256 i = 0; i < assets.length; i++) {
            DataTypes.MintAsset memory asset = assets[i];

            IGyroVault vault = IGyroVault(asset.destinationVault);
            address lpTokenAddress = vault.lpToken();

            uint256 lpTokenAmount;
            uint256 vaultTokenAmount;

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

            (vaultTokenAmount, err) = vault.dryDepositFor(address(reserve), lpTokenAmount);
            if (bytes(err).length > 0) {
                return (0, err);
            }

            vaultAmounts[i] = DataTypes.MonetaryAmount({
                tokenAddress: asset.destinationVault,
                amount: vaultTokenAmount
            });
        }

        uint256 mintFeeFraction = gyroConfig.getUint(ConfigKeys.MINT_FEE);
        uint256 usdValue = assetPricer.getBasketUSDValue(vaultAmounts);
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

    function _getVaultInfo(
        DataTypes.RedeemAsset calldata asset,
        DataTypes.VaultInfo[] memory vaultInfo
    ) internal pure returns (DataTypes.VaultInfo memory) {
        uint256 length = vaultInfo.length;
        for (uint256 i = 0; i < length; i++) {
            DataTypes.VaultInfo memory info = vaultInfo[i];
            if (info.vault == asset.originVault) {
                return info;
            }
        }
        revert(Errors.INVALID_ARGUMENT);
    }
}
