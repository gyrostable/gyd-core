// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "OpenZeppelin/openzeppelin-contracts@4.3.2/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.3.2/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IMotherBoard.sol";
import "../interfaces/IVaultRouter.sol";
import "../interfaces/IVault.sol";
import "../interfaces/ILPTokenExchangerRegistry.sol";
import "../interfaces/ILPTokenExchanger.sol";
import "../interfaces/IPAMM.sol";
import "../interfaces/IGyroConfig.sol";
import "../interfaces/IGYDToken.sol";
import "../interfaces/IFeeBank.sol";

import "../libraries/DataTypes.sol";
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

    /// @inheritdoc IMotherBoard
    IGYDToken public override gydToken;

    /// @inheritdoc IMotherBoard
    IVaultRouter public override vaultRouter;

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

    constructor(
        address gydTokenAddress,
        address exchangerRegistryAddress,
        address reserveAddress,
        address gyroConfigAddress
    ) {
        gydToken = IGYDToken(gydTokenAddress);
        exchangerRegistry = ILPTokenExchangerRegistry(exchangerRegistryAddress);
        reserve = IReserve(reserveAddress);
        gyroConfig = IGyroConfig(gyroConfigAddress);
    }

    /// @inheritdoc IMotherBoard
    function setVaultRouter(address vaultRouterAddress) external override governanceOnly {
        vaultRouter = IVaultRouter(vaultRouterAddress);
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
            DataTypes.MintAsset memory asset = assets[i];

            IVault vault = IVault(asset.destinationVault);
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
            vaultTokenAmount = vault.depositFor(lpTokenAmount, address(reserve));

            vaultAmounts[i] = DataTypes.MonetaryAmount({
                tokenAddress: asset.destinationVault,
                amount: vaultTokenAmount
            });
        }

        uint256 mintFeeFraction = gyroConfig.getMintFee();
        uint256 gyroToMint = pamm.calculateAndRecordGYDToMint(vaultAmounts, mintFeeFraction);

        uint256 feeToPay = gyroToMint.mulUp(mintFeeFraction);

        uint256 remainingGyro = gyroToMint - feeToPay;

        require(remainingGyro >= minReceivedAmount, Errors.NOT_ENOUGH_GYRO_MINTED);
        gydToken.mint(gyroToMint);
        gydToken.safeApprove(address(feeBank), feeToPay);
        feeBank.depositFees(address(gydToken), feeToPay);

        gydToken.safeTransfer(msg.sender, remainingGyro);

        return gyroToMint;
    }

    /// @inheritdoc IMotherBoard
    function redeem(DataTypes.RedeemAsset[] calldata assets, uint256 maxRedeemedAmount)
        external
        override
        returns (uint256 redeemedGYDAmount)
    {
        DataTypes.MonetaryAmount[] memory vaultAmounts = new DataTypes.MonetaryAmount[](
            assets.length
        );

        for (uint256 i = 0; i < assets.length; i++) {
            DataTypes.RedeemAsset memory asset = assets[i];

            IVault vault = IVault(asset.originVault);
            address lpTokenAddress = vault.lpToken();

            uint256 outputTokenAmount;
            uint256 lpTokenAmount = vault.withdraw(asset.vaultTokenAmount);
        }

        return 0;
    }

    /// @inheritdoc IMotherBoard
    function dryMint(DataTypes.MintAsset[] calldata assets, uint256 minReceivedAmount)
        external
        override
        returns (uint256 mintedGYDAmount, string memory err)
    {
        DataTypes.MonetaryAmount[] memory vaultAmounts = new DataTypes.MonetaryAmount[](
            assets.length
        );

        for (uint256 i = 0; i < assets.length; i++) {
            DataTypes.MintAsset memory asset = assets[i];

            IVault vault = IVault(asset.destinationVault);
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

            (vaultTokenAmount, err) = vault.dryDepositFor(lpTokenAmount, address(reserve));
            if (bytes(err).length > 0) {
                return (0, err);
            }

            vaultAmounts[i] = DataTypes.MonetaryAmount({
                tokenAddress: asset.destinationVault,
                amount: vaultTokenAmount
            });
        }

        uint256 mintFeeFraction = gyroConfig.getMintFee();
        mintedGYDAmount = pamm.calculateGYDToMint(vaultAmounts, mintFeeFraction);

        uint256 feeToPay = mintedGYDAmount.mulUp(mintFeeFraction);

        uint256 remainingGyro = mintedGYDAmount - feeToPay;

        if (remainingGyro < minReceivedAmount) {
            err = Errors.NOT_ENOUGH_GYRO_MINTED;
        }
    }

    /// @inheritdoc IMotherBoard
    function dryRedeem(
        DataTypes.MonetaryAmount[] calldata outputMonetaryAmounts,
        uint256 maxRedeemedAmount
    ) external override returns (uint256 redeemedGYDAmount, string memory err) {
        return (0, "");
    }
}
