// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "OpenZeppelin/openzeppelin-contracts@4.1.0/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.1.0/contracts/token/ERC20/IERC20.sol";

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
    function mint(DataTypes.TokenAmount[] memory inputTokenAmounts, uint256 minMintedAmount)
        external
        override
        returns (uint256 mintedGYDAmount)
    {
        DataTypes.Route[] memory routes = vaultRouter.computeInputRoutes(inputTokenAmounts);

        DataTypes.TokenAmount[] memory vaultTokenAmounts = new DataTypes.TokenAmount[](
            routes.length
        );

        for (uint256 i = 0; i < routes.length; i++) {
            DataTypes.Route memory route = routes[i];
            IVault vault = IVault(route.vaultAddress);
            address lpTokenAddress = vault.lpToken();

            ILPTokenExchanger exchanger = exchangerRegistry.getTokenExchanger(lpTokenAddress);

            uint256 lpTokenAmount = exchanger.deposit(route.tokenAmount);

            uint256 vaultTokenAmount = vault.depositFor(lpTokenAmount, address(reserve));
            vaultTokenAmounts[i] = DataTypes.TokenAmount({
                token: address(vault),
                amount: vaultTokenAmount
            });
        }

        uint256 mintFeeFraction = gyroConfig.getMintFee();
        uint256 gyroToMint = pamm.calculateAndRecordGYDToMint(vaultTokenAmounts, mintFeeFraction);

        uint256 feeToPay = gyroToMint.mulUp(mintFeeFraction);

        uint256 remainingGyro = gyroToMint - feeToPay;

        require(remainingGyro >= minMintedAmount, Errors.NOT_ENOUGH_GYRO_MINTED);
        gydToken.mint(gyroToMint);
        gydToken.safeApprove(address(feeBank), feeToPay);
        feeBank.depositFees(address(gydToken), feeToPay);

        gydToken.safeTransfer(msg.sender, remainingGyro);

        return gyroToMint;
    }

    /// @inheritdoc IMotherBoard
    function redeem(DataTypes.TokenAmount[] memory outputTokenAmounts, uint256 maxRedeemedAmount)
        external
        override
        returns (uint256 redeemedGYDAmount)
    {
        return 0;
    }

    /// @inheritdoc IMotherBoard
    function dryMint(DataTypes.TokenAmount[] memory inputTokenAmounts, uint256 minMintedAmount)
        external
        override
        returns (uint256 error, uint256 mintedGYDAmount)
    {}

    /// @inheritdoc IMotherBoard
    function dryRedeem(DataTypes.TokenAmount[] memory outputTokenAmounts, uint256 maxRedeemedAmount)
        external
        override
        returns (uint256 error, uint256 redeemedGYDAmount)
    {
        return (0, 0);
    }
}
