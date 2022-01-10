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
import "../interfaces/IPriceOracle.sol";

import "../libraries/DataTypes.sol";
import "../libraries/ConfigKeys.sol";
import "../libraries/Errors.sol";
import "../libraries/FixedPoint.sol";

import "./auth/Governable.sol";

/// @title MotherBoard is the central contract connecting the different pieces
/// of the Gyro protocol
contract Motherboard is IMotherBoard, Governable {
    using FixedPoint for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IGYDToken;

    // NOTE: dryMint and dryRedeem should be calling the safety check functions to ensure that the Reserve will remain stable.

    struct Addresses {
        address gydToken;
        address exchangerRegistry;
        address pamm;
        address gyroConfig;
        address feeBank;
        address reserve;
        address priceOracle;
    }

    /// @inheritdoc IMotherBoard
    IGYDToken public override gydToken;

    /// @inheritdoc IMotherBoard
    IPAMM public override pamm;

    /// @inheritdoc IMotherBoard
    ILPTokenExchangerRegistry public override exchangerRegistry;

    /// @inheritdoc IMotherBoard
    IReserve public override reserve;

    /// @inheritdoc IMotherBoard
    IGyroConfig public override gyroConfig;

    /// @inheritdoc IMotherBoard
    IFeeBank public override feeBank;

    /// @inheritdoc IMotherBoard
    IPriceOracle public override priceOracle;

    constructor(Addresses memory addresses) {
        gydToken = IGYDToken(addresses.gydToken);
        exchangerRegistry = ILPTokenExchangerRegistry(addresses.exchangerRegistry);
        pamm = IPAMM(addresses.pamm);
        reserve = IReserve(addresses.reserve);
        gyroConfig = IGyroConfig(addresses.gyroConfig);
        feeBank = IFeeBank(addresses.feeBank);
        priceOracle = IPriceOracle(addresses.priceOracle);
        gydToken.safeApprove(addresses.feeBank, type(uint256).max);
    }

    /// @inheritdoc IMotherBoard
    function setPAMM(address pamAddress) external override governanceOnly {
        pamm = IPAMM(pamAddress);
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
            address lpTokenAddress = vault.lpToken();

            IERC20(asset.inputToken).safeTransferFrom(msg.sender, address(this), asset.inputAmount);

            uint256 lpTokenAmount;
            uint256 vaultTokenAmount;

            if (asset.inputToken == lpTokenAddress) {
                lpTokenAmount = asset.inputAmount;
            } else {
                ILPTokenExchanger exchanger = exchangerRegistry.getTokenExchanger(lpTokenAddress);
                lpTokenAmount = exchanger.deposit(
                    DataTypes.MonetaryAmount(asset.inputToken, asset.inputAmount)
                );
            }
            vaultTokenAmount = vault.depositFor(address(reserve), lpTokenAmount);

            vaultAmounts[i] = DataTypes.MonetaryAmount({
                tokenAddress: asset.destinationVault,
                amount: vaultTokenAmount
            });
        }

        uint256 mintFeeFraction = gyroConfig.getUint(ConfigKeys.MINT_FEE);
        uint256 usdValue = priceOracle.getUSDValue(vaultAmounts);
        uint256 gyroToMint = pamm.mint(usdValue);

        uint256 feeToPay = gyroToMint.mulUp(mintFeeFraction);

        uint256 remainingGyro = gyroToMint - feeToPay;

        require(remainingGyro >= minReceivedAmount, Errors.TOO_MUCH_SLIPPAGE);

        gydToken.mint(gyroToMint);
        feeBank.depositFees(address(gydToken), feeToPay);

        gydToken.safeTransfer(msg.sender, remainingGyro);

        return gyroToMint;
    }

    /// @inheritdoc IMotherBoard
    function redeem(uint256, DataTypes.RedeemAsset[] calldata assets)
        external
        pure
        override
        returns (uint256 redeemedGYDAmount)
    {
        // NOTE: remove pure when implementing

        // DataTypes.MonetaryAmount[] memory vaultAmounts = new DataTypes.MonetaryAmount[](
        //     assets.length
        // );

        for (uint256 i = 0; i < assets.length; i++) {
            // DataTypes.RedeemAsset memory asset = assets[i];
            // IGyroVault vault = IGyroVault(asset.originVault);
            // address lpTokenAddress = vault.lpToken();
            // uint256 lpTokenAmount = vault.withdraw(asset.vaultTokenAmount);
        }

        return 0;
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
        uint256 usdValue = priceOracle.getUSDValue(vaultAmounts);
        mintedGYDAmount = pamm.computeMintAmount(usdValue);

        uint256 feeToPay = mintedGYDAmount.mulUp(mintFeeFraction);

        uint256 remainingGyro = mintedGYDAmount - feeToPay;

        if (remainingGyro < minReceivedAmount) {
            err = Errors.TOO_MUCH_SLIPPAGE;
        }
    }

    /// @inheritdoc IMotherBoard
    function dryRedeem(DataTypes.MonetaryAmount[] memory, uint256)
        external
        pure
        override
        returns (uint256 redeemedGYDAmount, string memory err)
    {
        return (0, "");
    }
}
