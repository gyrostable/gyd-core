// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../interfaces/IMotherBoard.sol";
import "../interfaces/IVaultRouter.sol";
import "../interfaces/IVault.sol";
import "../interfaces/ILPTokenExchangerRegistry.sol";
import "../interfaces/ILPTokenExchanger.sol";

import "../libraries/DataTypes.sol";
import "../libraries/Errors.sol";

/// @title MotherBoard is the central contract connecting the different pieces
/// of the Gyro protocol
contract Motherboard is IMotherBoard {
    // NOTE: dryMint and dryRedeem should be calling the safety check functions to ensure that the Reserve will remain stable.

    /// @inheritdoc IMotherBoard
    address public override GYDTokenAddress;

    /// @inheritdoc IMotherBoard
    address public override vaultRouterAddress;

    /// @inheritdoc IMotherBoard
    address public override PAMMAddress;

    /// @inheritdoc IMotherBoard
    address public override exchangerRegistryAddress;

    /// @inheritdoc IMotherBoard
    address public override reserveAddress;

    constructor(
        address _gydTokenAddress,
        address _exchangerRegistryAddress,
        address _reserveAddress
    ) {
        GYDTokenAddress = _gydTokenAddress;
        exchangerRegistryAddress = _exchangerRegistryAddress;
        reserveAddress = _reserveAddress;
    }

    /// @inheritdoc IMotherBoard
    function setVaultRouterAddress(address _vaultRouterAddress) external override {
        vaultRouterAddress = _vaultRouterAddress;
    }

    /// @inheritdoc IMotherBoard
    function setPAMMAddress(address _pamAddress) external override {
        PAMMAddress = _pamAddress;
    }

    /// @inheritdoc IMotherBoard
    function mint(
        address[] memory inputTokens,
        uint256[] memory inputAmounts,
        uint256 minMintedAmount
    ) external override returns (uint256 mintedGYDAmount) {
        require(inputTokens.length == inputAmounts.length, Errors.TOKEN_AND_AMOUNTS_LENGTH_DIFFER);

        IVaultRouter vaultRouter = IVaultRouter(vaultRouterAddress);
        ILPTokenExchangerRegistry exchangerRegistry =
            ILPTokenExchangerRegistry(exchangerRegistryAddress);

        DataTypes.Route[] memory routes = vaultRouter.computeInputRoutes(inputTokens, inputAmounts);

        address[] memory lpTokens = new address[](routes.length);
        uint256[] memory lpTokenAmounts = new uint256[](routes.length);
        uint256[] memory vaultTokenAmounts = new uint256[](routes.length);

        for (uint256 i = 0; i < routes.length; i++) {
            DataTypes.Route memory route = routes[i];
            IVault vault = IVault(route.vaultAddress);
            address lpToken = vault.lpToken();

            ILPTokenExchanger exchanger =
                ILPTokenExchanger(exchangerRegistry.getTokenExchanger(lpToken));

            uint256 lpTokenAmount = exchanger.deposit(route.token, route.amount, lpToken);
            lpTokens[i] = lpToken;
            lpTokenAmounts[i] = lpTokenAmount;

            uint256 vaultTokenAmount = vault.depositFor(lpTokenAmount, reserveAddress);
            vaultTokenAmounts[i] = vaultTokenAmount;
        }

        return 0;
    }

    /// @inheritdoc IMotherBoard
    function redeem(
        address[] memory outputTokens,
        uint256[] memory outputAmounts,
        uint256 maxRedeemedAmount
    ) external override returns (uint256 redeemedGYDAmount) {
        return 0;
    }

    /// @inheritdoc IMotherBoard
    function dryMint(
        address[] memory inputTokens,
        uint256[] memory inputAmounts,
        uint256 minMintedAmount
    ) external override returns (uint256 error, uint256 mintedGYDAmount) {}

    /// @inheritdoc IMotherBoard
    function dryRedeem(
        address[] memory outputTokens,
        uint256[] memory outputAmounts,
        uint256 maxRedeemedAmount
    ) external override returns (uint256 error, uint256 redeemedGYDAmount) {
        return (0, 0);
    }
}
