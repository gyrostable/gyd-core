// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "./../libraries/DataTypes.sol";
import "../contracts/auth/Governable.sol";

/// @title IPAMM is the pricing contract for the Primary Market
interface IPAMM {
    /// @notice this event is emitted when the system parameters are updated
    event SystemParamsUpdated(uint64 alphaBar, uint64 xuBar, uint64 thetaBar, uint64 outflowMemory);

    // NB gas optimization, don't need to use uint64
    struct Params {
        uint64 alphaBar; // ᾱ ∊ [0,1]
        uint64 xuBar; // x̄_U ∊ [0,1]
        uint64 thetaBar; // θ̄ ∊ [0,1]
        uint64 outflowMemory; // this is [0,1]
    }

    /// @notice Quotes the amount of GYD to mint for the given USD amount
    /// @param usdAmount the USD value to add to the reserve
    /// @param reserveUSDValue the current USD value of the reserve
    /// @return the amount of GYD to mint
    function computeMintAmount(
        uint256 usdAmount,
        uint256 reserveUSDValue
    ) external view returns (uint256);

    /// @notice Quotes and records the amount of GYD to mint for the given USD amount.
    /// NB that reserveUSDValue is added here to future proof the implementation
    /// @param usdAmount the USD value to add to the reserve
    /// @return the amount of GYD to mint
    function mint(uint256 usdAmount, uint256 reserveUSDValue) external returns (uint256);

    /// @notice Quotes the output USD value given an amount of GYD
    /// @param gydAmount the amount GYD to redeem
    /// @param reserveUSDValue total value of the reserve in USD. Can be pulled from
    /// ReserveManager.getReserveState()
    /// @return the USD value to redeem
    function computeRedeemAmount(
        uint256 gydAmount,
        uint256 reserveUSDValue
    ) external view returns (uint256);

    /// @notice Current redemption level
    function getRedemptionLevel() external view returns (uint256);

    /// @notice Quotes and records the output USD value given an amount of GYD
    /// @param gydAmount the amount GYD to redeem
    /// @param reserveUSDValue total value of the reserve in USD. Can be pulled from
    /// ReserveManager.getReserveState()
    /// @return the USD value to redeem
    function redeem(uint256 gydAmount, uint256 reserveUSDValue) external returns (uint256);

    /// @notice Allows for the system parameters to be updated
    function setSystemParams(Params memory params) external;

    /// @notice Retrieves the system parameters to be updated
    function systemParams() external view returns (Params memory);

    /// @notice Internal value that may be useful to predict the state of the system under
    /// different scenarios. This value is the 'anchor reserve value', normalized to 'anchor GYD
    /// supply' = 1.
    /// @dev This function extends the meaning of the anchor reserve value to cases where it's not
    /// formally defined as follows. Let r be the current reserve value, discounted by the
    /// configured redeem discount ratio.
    /// - If r >= 1, this returns 1.
    /// - If thetaBar < r < 1, this returns the normalized anchor reserve value like in the PAMM
    ///   mathematics paper.
    /// - If r <= thetaBar, this returns r.
    /// Note that, in the two edge cases, the mapping is not 1:1 and the anchor reserve value is not
    /// actually used by the PAMM to compute redemption amounts.
    function getNormalizedAnchoredReserveValue(uint256 reserveUSDValue) external view returns (uint256);

    /// @notice Like computeRedeemAmount(gydAmount, reserveUSDValue) but at a hypothetical different
    /// starting state. This can be used to simulate the impact of different changes to the system
    /// state, e.g., prior redemptions or time passing.
    /// @param reserveUSDValue hypothetical total value of the reserve in USD.
    /// @param redemptionLevel hypothetical redemption level.
    /// @param totalGyroSupply hypothetical value of gydToken.totalSupply().
    function getNormalizedAnchoredReserveValueAtState(
        uint256 reserveUSDValue,
        uint256 redemptionLevel,
        uint256 totalGyroSupply
    ) external view returns (uint256);
}
