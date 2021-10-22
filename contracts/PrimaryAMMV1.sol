pragma solidity ^0.8.4;

// SPDX-License-Identifier: MIT

import "../libraries/LogExpMath.sol";
import "../libraries/FixedPoint.sol";

/// @notice Implements the primary AMM pricing mechanism
contract PrimaryAMMV1 {
    using LogExpMath for uint256;
    using FixedPoint for uint256;

    uint256 constant ONE = 1e18;
    uint256 constant TWO = 2e18;

    enum Region {
        CASE_i,
        CASE_I_ii,
        CASE_I_iii,
        CASE_II_H,
        CASE_II_L,
        CASE_III_H,
        CASE_III_L
    }

    struct State {
        uint256 redemptionLevel; // x
        uint256 reserveValue; // b
        uint256 totalGyroSupply; // y
    }

    struct Params {
        uint64 decaySlopeLowerBound; // α∊ [0,1]
        uint64 stableRedeemThresholdUpperBound; // x̄_U ∊ [0,1]
        uint64 targetReserveRatioFloor; // ϑ ∊ [0,1]
    }

    struct DerivedParams {
        uint256 reserveValueThresholdFirstRegion; // b_a^{I/II}
        uint256 reserveValueThresholdSecondRegion; // b_a^{II/III}
        uint256 lowerRedemptionThreshold; // x_L^{I/II}
        uint256 reserveHighLowThreshold; // ba^{h/l}
        uint256 lastRegionHighLowThreshold; // ba^{H/L}
        uint256 upperBoundRedemptionThreshold; // x_U^{h/l}
        uint256 slopeThreshold; // α^{H/L}
    }

    /// @notice parmaters of the primary AMM
    Params public systemParams;

    /// @notice current state of the primary AMM
    State public systemState;

    /// @notice Initializes the PAAM with the given system parameters
    constructor(Params memory params) {
        systemParams = params;
    }

    /// Helpers to compute various parameters

    function computeSlope(
        uint256 ba,
        uint256 ya,
        uint256 targetReserveRatio,
        uint256 slopeLowerBound
    ) internal pure returns (uint256) {
        uint256 ra = ba.divDown(ya);
        uint256 slope;
        if (ra >= (ONE + targetReserveRatio) / 2) {
            slope = (TWO * (ONE - ra)) / ya;
        } else {
            slope = (ONE - targetReserveRatio)**2 / (ba - targetReserveRatio.mulDown(ya)) / 2;
        }
        return slope.max(slopeLowerBound);
    }

    function computeFixedReserve(
        uint256 x,
        uint256 ba,
        uint256 ya,
        uint256 alpha,
        uint256 xu,
        uint256 xl
    ) internal pure returns (uint256) {
        if (x <= xu) {
            return ba - x;
        }
        if (x <= xl) {
            return ba - x + (alpha * (x - xu).squareDown()) / TWO;
        }
        // x > xl:
        uint256 rl = ONE - alpha.mulDown(xl - xu);
        return rl.mulDown(ya - x);
    }

    function computeLowerRedemptionThreshold(
        uint256 ba,
        uint256 ya,
        uint256 alpha,
        uint256 xu
    ) internal pure returns (uint256) {
        if (ba.divDown(ya) >= ONE) {
            return ya;
        }
        return ya - ((ya - xu).squareUp() - ((TWO * (ya - ba)) / alpha)).sqrt();
    }

    function computeUpperRedemptionThreshold(
        uint256 ba,
        uint256 ya,
        uint256 alpha,
        uint256 stableRedeemThresholdUpperBound,
        uint256 targetUtilizationCeiling
    ) internal pure returns (uint256) {
        uint256 delta = ya - ba;
        uint256 xu;
        if (alpha.mulDown(delta) <= targetUtilizationCeiling**2 / TWO) {
            uint256 rh = ((TWO * delta) / alpha);
            xu = ya.squareDown() < rh ? 0 : ya - rh.sqrt();
        } else {
            xu =
                ya -
                delta.divDown(targetUtilizationCeiling) -
                targetUtilizationCeiling.divDown(2 * alpha);
        }

        uint256 xuMax = stableRedeemThresholdUpperBound.mulUp(ya);
        return xu.min(xuMax);
    }

    function computeRelativeReserve(
        uint256 xu,
        uint256 ya,
        Params memory params
    ) internal pure returns (uint256) {
        uint256 alpha = uint256(params.decaySlopeLowerBound).divDown(ya);
        return computeRelativeReserve(xu, ya, params, alpha);
    }

    function computeRelativeReserve(
        uint256 xu,
        uint256 ya,
        Params memory params,
        uint256 alpha
    ) internal pure returns (uint256) {
        require(ya >= xu, "ya must be greater than xu");

        uint256 yz = ya - xu;
        if (ONE - alpha.mulDown(yz) >= params.targetReserveRatioFloor)
            return ya - (alpha * yz.squareDown()) / TWO;
        uint256 targetUsage = ONE - params.targetReserveRatioFloor;
        return ya - targetUsage.mulDown(yz) + targetUsage**2 / (2 * params.decaySlopeLowerBound);
    }

    function createDerivedParams(Params memory params)
        internal
        pure
        returns (DerivedParams memory)
    {
        DerivedParams memory derived;

        derived.reserveValueThresholdFirstRegion = computeRelativeReserve(
            params.stableRedeemThresholdUpperBound,
            ONE,
            params
        );
        derived.reserveValueThresholdSecondRegion = computeRelativeReserve(0, ONE, params);

        derived.lowerRedemptionThreshold = computeLowerRedemptionThreshold(
            derived.reserveValueThresholdFirstRegion,
            ONE,
            params.decaySlopeLowerBound,
            params.stableRedeemThresholdUpperBound
        );

        uint256 targetUtilizationCeiling = ONE - params.targetReserveRatioFloor;
        derived.reserveHighLowThreshold =
            ONE -
            (targetUtilizationCeiling**2) /
            (2 * params.decaySlopeLowerBound);

        derived.upperBoundRedemptionThreshold = computeUpperRedemptionThreshold(
            derived.reserveHighLowThreshold,
            ONE,
            params.decaySlopeLowerBound,
            params.stableRedeemThresholdUpperBound,
            targetUtilizationCeiling
        );

        derived.lastRegionHighLowThreshold = (ONE + params.targetReserveRatioFloor) / 2;
        derived.slopeThreshold = computeSlope(
            derived.lastRegionHighLowThreshold,
            ONE,
            params.targetReserveRatioFloor,
            params.decaySlopeLowerBound
        );

        return derived;
    }

    function computeReserve(
        uint256 x,
        uint256 ba,
        uint256 ya,
        Params memory params
    ) internal pure returns (uint256) {
        uint256 alpha = computeSlope(
            ba,
            ya,
            params.targetReserveRatioFloor,
            params.decaySlopeLowerBound
        );
        uint256 xu = computeUpperRedemptionThreshold(
            ba,
            ya,
            alpha,
            params.stableRedeemThresholdUpperBound,
            ONE - params.targetReserveRatioFloor
        );
        uint256 xl = computeLowerRedemptionThreshold(ba, ya, alpha, xu);
        return computeFixedReserve(x, ba, ya, alpha, xu, xl);
    }

    function isInFirstRegion(
        State memory scaledState,
        Params memory params,
        DerivedParams memory derived
    ) internal pure returns (bool) {
        return
            scaledState.reserveValue >=
            computeFixedReserve(
                scaledState.redemptionLevel,
                derived.reserveValueThresholdFirstRegion,
                ONE,
                params.decaySlopeLowerBound,
                params.stableRedeemThresholdUpperBound,
                derived.lowerRedemptionThreshold
            );
    }

    function isInSecondRegion(
        State memory scaledState,
        uint256 decaySlopeLowerBound,
        DerivedParams memory derived
    ) internal pure returns (bool) {
        return
            scaledState.reserveValue >=
            computeFixedReserve(
                scaledState.redemptionLevel,
                derived.reserveValueThresholdSecondRegion,
                ONE,
                decaySlopeLowerBound,
                0,
                ONE
            );
    }

    function isInSecondSubcase(
        State memory scaledState,
        uint256 decaySlopeLowerBound,
        DerivedParams memory derived
    ) internal pure returns (bool) {
        return
            scaledState.reserveValue >=
            computeFixedReserve(
                scaledState.redemptionLevel,
                derived.reserveHighLowThreshold,
                ONE,
                decaySlopeLowerBound,
                derived.upperBoundRedemptionThreshold,
                ONE
            );
    }

    function isInHighSubcase(State memory scaledState, DerivedParams memory derived)
        internal
        pure
        returns (bool)
    {
        return
            scaledState.reserveValue >=
            computeFixedReserve(
                scaledState.redemptionLevel,
                derived.lastRegionHighLowThreshold,
                ONE,
                derived.slopeThreshold,
                0,
                ONE
            );
    }

    function computeNextReserveValueRegion(
        State memory scaledState,
        Params memory params,
        DerivedParams memory derived
    ) internal pure returns (Region) {
        if (isInFirstRegion(scaledState, params, derived)) {
            // case I
            if (scaledState.redemptionLevel <= params.stableRedeemThresholdUpperBound)
                return Region.CASE_i;
            if (scaledState.redemptionLevel <= derived.lowerRedemptionThreshold)
                return Region.CASE_I_ii;
            return Region.CASE_I_iii;
        }

        if (isInSecondRegion(scaledState, params.decaySlopeLowerBound, derived)) {
            // case II
            if (isInSecondSubcase(scaledState, params.decaySlopeLowerBound, derived)) {
                // case h
                if (
                    scaledState.totalGyroSupply - scaledState.reserveValue <=
                    (scaledState.totalGyroSupply.squareDown() * params.decaySlopeLowerBound) / TWO
                ) return Region.CASE_i;
                return Region.CASE_II_H;
            }

            uint256 thetha = ONE - params.targetReserveRatioFloor;
            if (
                scaledState.reserveValue -
                    uint256(params.targetReserveRatioFloor).mulDown(scaledState.totalGyroSupply) >=
                thetha**2 / (2 * params.decaySlopeLowerBound)
            ) return Region.CASE_i;
            return Region.CASE_II_L;
        }

        if (isInHighSubcase(scaledState, derived)) {
            return Region.CASE_III_H;
        }

        return Region.CASE_III_L;
    }

    struct NextReserveValueVars {
        uint256 ya;
        uint256 reserveRatio;
        Region region;
        uint256 usedRatio;
        uint256 thetha;
    }

    function computeNextReserveValue(
        State memory scaledState,
        Params memory params,
        DerivedParams memory derived
    ) internal pure returns (uint256) {
        NextReserveValueVars memory vars;
        vars.ya = ONE;
        vars.reserveRatio = scaledState.reserveValue.divDown(scaledState.totalGyroSupply);
        Region region = computeNextReserveValueRegion(scaledState, params, derived);

        vars.usedRatio = ONE - vars.reserveRatio;
        vars.thetha = ONE - params.targetReserveRatioFloor;

        if (region == Region.CASE_i) {
            return scaledState.reserveValue + scaledState.redemptionLevel;
        }

        if (region == Region.CASE_I_ii) {
            uint256 xDiff = scaledState.redemptionLevel - params.stableRedeemThresholdUpperBound;
            return (scaledState.reserveValue +
                scaledState.redemptionLevel -
                (params.decaySlopeLowerBound * xDiff.squareDown()) /
                TWO);
        }

        if (region == Region.CASE_I_iii)
            return
                vars.ya -
                (vars.ya - params.stableRedeemThresholdUpperBound).mulDown(vars.usedRatio) +
                (vars.usedRatio**2 / (2 * params.decaySlopeLowerBound));

        if (region == Region.CASE_II_H) {
            uint256 delta = (params.decaySlopeLowerBound *
                (vars.usedRatio.divDown(params.decaySlopeLowerBound) +
                    (scaledState.totalGyroSupply / 2)).squareDown()) / TWO;
            return vars.ya - delta;
        }

        if (region == Region.CASE_II_L) {
            uint256 p = vars.thetha.mulDown(
                vars.thetha.divDown(2 * params.decaySlopeLowerBound) + scaledState.totalGyroSupply
            );
            uint256 d = 2 *
                (vars.thetha**2 / params.decaySlopeLowerBound).mulDown(
                    scaledState.reserveValue -
                        scaledState.totalGyroSupply.mulDown(params.targetReserveRatioFloor)
                );
            return vars.ya + d.sqrt() - p;
        }

        if (region == Region.CASE_III_H) {
            uint256 delta = (scaledState.totalGyroSupply - scaledState.reserveValue).divDown(
                (vars.ya - scaledState.redemptionLevel.squareDown())
            );
            return vars.ya - delta;
        }

        if (region == Region.CASE_III_L) {
            uint256 p = (scaledState.totalGyroSupply - scaledState.reserveValue + vars.thetha) / 2;
            uint256 q = (scaledState.totalGyroSupply - scaledState.reserveValue).mulDown(
                vars.thetha
            ) + vars.thetha.squareDown().mulDown(scaledState.redemptionLevel.squareDown()) / 4;
            uint256 delta = p - (p.squareDown() - q).sqrt();
            return vars.ya - delta;
        }

        revert("unknown region");
    }

    function computeRedeemAmount(
        State memory state,
        Params memory params,
        DerivedParams memory derived,
        uint256 amount
    ) internal pure returns (uint256) {
        uint256 nav = state.reserveValue.divDown(state.totalGyroSupply);

        if (nav >= ONE) {
            return amount;
        }

        if (nav <= params.targetReserveRatioFloor) {
            return nav.mulDown(amount);
        }

        State memory scaledState;
        uint256 ya = state.totalGyroSupply + state.redemptionLevel;

        scaledState.redemptionLevel = state.redemptionLevel.divDown(ya);
        scaledState.reserveValue = state.reserveValue.divDown(ya);
        scaledState.totalGyroSupply = state.totalGyroSupply.divDown(ya);

        uint256 normalizedReserveValue = computeNextReserveValue(scaledState, params, derived);
        uint256 reserveValue = normalizedReserveValue.mulDown(ya);

        uint256 nextReserveValue = computeReserve(
            state.redemptionLevel + amount,
            reserveValue,
            ya,
            params
        );
        return nextReserveValue - state.reserveValue;
    }

    function computeRedeemAmount(uint256 amount) external view returns (uint256) {
        if (amount == 0) return 0;
        Params memory params = systemParams;
        DerivedParams memory derived = createDerivedParams(params);
        return computeRedeemAmount(systemState, params, derived, amount);
    }

    function redeem(uint256 amount) external returns (uint256) {
        if (amount == 0) return 0;
        State storage state = systemState;
        Params memory params = systemParams;
        DerivedParams memory derived = createDerivedParams(params);
        uint256 redeemAmount = computeRedeemAmount(state, params, derived, amount);
        state.redemptionLevel += amount;
        state.totalGyroSupply -= amount;
        state.reserveValue -= redeemAmount;
        return redeemAmount;
    }
}
