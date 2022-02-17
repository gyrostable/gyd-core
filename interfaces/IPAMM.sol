// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./../libraries/DataTypes.sol";
import "../contracts/auth/Governable.sol";

/// @title IPAMM is the pricing contract for the Primary Market
interface IPAMM {
    /// @notice Quotes the amount of GYD to mint for the given USD amount
    /// @param usdAmount the USD value to add to the reserve
    /// @return the amount of GYD to mint
    function computeMintAmount(uint256 usdAmount, uint256 reserveUSDValue)
        external
        view
        returns (uint256);

    /// @notice Quotes and records the amount of GYD to mint for the given USD amount.
    /// NB that reserveUSDValue is added here to future proof the implementation
    /// @param usdAmount the USD value to add to the reserve
    /// @return the amount of GYD to mint
    function mint(uint256 usdAmount, uint256 reserveUSDValue) external returns (uint256);

    /// @notice Quotes the output USD value given an amount of GYD
    /// @param gydAmount the amount GYD to redeem
    /// @return the USD value to redeem
    function computeRedeemAmount(uint256 gydAmount, uint256 reserveUSDValue)
        external
        view
        returns (uint256);

    /// @notice Quotes and records the output USD value given an amount of GYD
    /// @param gydAmount the amount GYD to redeem
    /// @return the USD value to redeem
    function redeem(uint256 gydAmount, uint256 reserveUSDValue) external returns (uint256);

    /// @notice Allows for the system parameters to be updated
    function setSystemParams(
        uint64 alphaBar,
        uint64 xuBar,
        uint64 thetaBar,
        uint64 outflowMemory
    ) external;
}
