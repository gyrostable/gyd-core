// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/// @title IMotherBoard is the central contract connecting the different pieces
/// of the Gyro protocol
interface IMotherBoard {
    /// @dev The GYD token is not upgradable so this will always return the same value
    /// @return the address of the GYD token
    function GYDTokenAddress() external returns (address);

    /// @notice Returns the address of the vault router used to route the input tokens
    /// @return the address of the router
    function vaultRouterAddress() external returns (address);

    /// @notice Sets the address for the vault router
    /// @param _vaultRouterAddress the address to be used as the Vault Router
    function setVaultRouterAddress(address _vaultRouterAddress) external;

    /// @notice Returns the address for the PAMM
    /// @return the PAMM address
    function PAMMAddress() external returns (address);

    /// @notice Set the address of the primary AMM (P-AMM) to be used when minting and redeeming GYD tokens
    /// @param _pamAddress the address of the P-AMM to use
    function setPAMMAddress(address _pamAddress) external;

    /// @notice Main minting function to be called by a depositor
    /// This mints using the exact input amount and mints at least `minMintedAmount`
    /// All the `inputTokens` should be approved for the motherboard to spend at least
    /// `inputAmounts` on behalf of the sender
    /// @param inputTokens the input tokens used to mint GYD
    /// @param inputAmounts the amounts of each tokens, should be the same length as `tokens`
    /// @param minMintedAmount the minimum amount of GYD to be minted
    /// @return mintedGYDAmount GYD token minted amount
    function mint(
        address[] memory inputTokens,
        uint256[] memory inputAmounts,
        uint256 minMintedAmount
    ) external returns (uint256 mintedGYDAmount);

    /// @notice Main redemption function to be called by a withdrawer
    /// This redeems using at most `maxRedeemedAmount` of GYD and returns the
    /// exact outputs as specified by `tokens` and `amounts`
    /// @param outputTokens the output tokens to return against GYD
    /// @param outputAmounts the output amounts for each token
    /// @param maxRedeemedAmount the maximum amount of GYD to redeem
    /// @return redeemedGYDAmount the amount of redeemed GYD tokens
    function redeem(
        address[] memory outputTokens,
        uint256[] memory outputAmounts,
        uint256 maxRedeemedAmount
    ) external returns (uint256 redeemedGYDAmount);

    /// @notice Simulates a mint to know whether it would succeed and how much would be minted
    /// The parameters are the same as the `mint` function
    /// @param inputTokens the input tokens used to mint GYD
    /// @param inputAmounts the amounts of each tokens, should be the same length as `tokens`
    /// @param minMintedAmount the minimum amount of GYD to be minted
    /// @return error a non-zero value in case an error would happen when minting GYD
    /// @return mintedGYDAmount the amount that would be minted, or 0 if it an error would occur
    function simulateMint(
        address[] memory inputTokens,
        uint256[] memory inputAmounts,
        uint256 minMintedAmount
    ) external returns (uint256 error, uint256 mintedGYDAmount);

    /// @notice Simulates a redemption execution and returns the amount of GYD
    /// redeems or an error code if the redeem would fail
    /// @param outputTokens the output tokens to return against GYD
    /// @param outputAmounts the output amounts for each token
    /// @param maxRedeemedAmount the maximum amount of GYD to redeem
    /// @return error a non-zero value in case an error would happen when redeeming
    /// @return redeemedGYDAmount the amount of redeemed GYD tokens
    function simulateRedeem(
        address[] memory outputTokens,
        uint256[] memory outputAmounts,
        uint256 maxRedeemedAmount
    ) external returns (uint256 error, uint256 redeemedGYDAmount);
}
