// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./IGyroConfig.sol";
import "./ILPTokenExchangerRegistry.sol";
import "./IGYDToken.sol";
import "./IReserve.sol";
import "./IPAMM.sol";
import "./IVaultRouter.sol";
import "./IFeeBank.sol";

/// @title IMotherBoard is the central contract connecting the different pieces
/// of the Gyro protocol
interface IMotherBoard {
    /// @dev The GYD token is not upgradable so this will always return the same value
    /// @return the address of the GYD token
    function gydToken() external view returns (IGYDToken);

    /// @notice Returns the address for the PAMM
    /// @return the PAMM address
    function pamm() external view returns (IPAMM);

    /// @notice Returns the address for the reserve
    /// @return the address of the reserve
    function reserve() external view returns (IReserve);

    /// @notice Returns the address for the fee bank
    /// @return the address of the fee bank
    function feeBank() external view returns (IFeeBank);

    /// @notice Returns the address of the exchanger registry
    /// @return the exchanger registry address
    function exchangerRegistry() external view returns (ILPTokenExchangerRegistry);

    /// @notice Set the address of the primary AMM (P-AMM) to be used when minting and redeeming GYD tokens
    /// @param pamAddress the address of the P-AMM to use
    function setPAMM(address pamAddress) external;

    /// @notice Returns the address of the global configuration
    /// @return the global configuration address
    function gyroConfig() external view returns (IGyroConfig);

    /// @notice Main minting function to be called by a depositor
    /// This mints using the exact input amount and mints at least `minMintedAmount`
    /// All the `inputTokens` should be approved for the motherboard to spend at least
    /// `inputAmounts` on behalf of the sender
    /// @param assets the assets and associated amounts used to mint GYD
    /// @param minReceivedAmount the minimum amount of GYD to be minted
    /// @return mintedGYDAmount GYD token minted amount
    function mint(DataTypes.MintAsset[] calldata assets, uint256 minReceivedAmount)
        external
        returns (uint256 mintedGYDAmount);

    /// @notice Main redemption function to be called by a withdrawer
    /// This redeems using at most `maxRedeemedAmount` of GYD and returns the
    /// exact outputs as specified by `tokens` and `amounts`
    /// @param assets the output tokens and associated amounts to return against GYD
    /// @param maxRedeemedAmount the maximum amount of GYD to redeem
    /// @return redeemedGYDAmount the amount of redeemed GYD tokens
    function redeem(DataTypes.RedeemAsset[] calldata assets, uint256 maxRedeemedAmount)
        external
        returns (uint256 redeemedGYDAmount);

    /// @notice Simulates a mint to know whether it would succeed and how much would be minted
    /// The parameters are the same as the `mint` function
    /// @param assets the assets and associated amounts used to mint GYD
    /// @param minReceivedAmount the minimum amount of GYD to be minted
    /// @return mintedGYDAmount the amount that would be minted, or 0 if it an error would occur
    /// @return err a non-empty error message in case an error would happen when minting
    function dryMint(DataTypes.MintAsset[] calldata assets, uint256 minReceivedAmount)
        external
        returns (uint256 mintedGYDAmount, string memory err);

    /// @notice Simulates a redemption execution and returns the amount of GYD
    /// redeems or an error code if the redeem would fail
    /// @param outputMonetaryAmounts the output tokens and associated amounts to return against GYD
    /// @param maxRedeemedAmount the maximum amount of GYD to redeem
    /// @return redeemedGYDAmount the amount of redeemed GYD tokens
    /// @return err a non-empty error message in case an error would happen when redeeming
    function dryRedeem(
        DataTypes.MonetaryAmount[] calldata outputMonetaryAmounts,
        uint256 maxRedeemedAmount
    ) external returns (uint256 redeemedGYDAmount, string memory err);
}
