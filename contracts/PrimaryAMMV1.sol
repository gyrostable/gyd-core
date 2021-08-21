pragma solidity ^0.8.4;

// SPDX-License-Identifier: MIT

import "../libraries/LogExpMath.sol";

/// @notice Implements the primary AMM pricing mechanism
contract PrimaryAMMV1 {
    using LogExpMath for uint256;

    uint256 constant ONE = 1e18;

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
        uint256 redemptionLevel;
        uint256 totalGyroSupply;
        uint256 reserveValue;
    }

    struct Params {
        uint64 decaySlopeLowerBound; // α∊ (0,1)
        uint64 stableRedeemThresholdUpperBound; // x̄_U ∊ (0,1)
        uint64 targetReserveRatioFloor; // ϑ ∊ (0,1)
    }

    struct DerivedParams {
        uint256 reserveValueThresholdFirstRegion; // b_a^{I/II}
        uint256 reserveValueThresholdSecondRegion; // b_a^{II/III}
        uint256 lowerRedemptionThreshold; // x_L^{I/II}
        uint256 reserveHighLowThreshold; // ba^{h/l}
        uint256 upperBoundRedemptionThreshold; // x_U^{h/l}
        uint256 slopeThreshold; // α^{H/L}
    }

    /// @notice parmaters of the primary AMM
    Params systemParams;

    /// @notice current state of the primary AMM
    State systemState;

    /// Helpers to compute various parameters

    function computeSlope(
        uint256 ba,
        uint256 ya,
        uint256 slopeLowerBound
    ) internal pure returns (uint256) {
        uint256 ra = ba / ya;
        if (ra >= (1 + slopeLowerBound) / 2) return (2 * (1 - ra)) / ya;
        else return (1 - slopeLowerBound)**2 / (ba - slopeLowerBound * ya) / 2;
    }

    function computeFixedReserve(
        uint256 x,
        uint256 ba,
        uint256 ya,
        uint256 alpha,
        uint256 xu,
        uint256 xl
    ) internal pure returns (uint256) {
        if (x <= xu) return ba - x;
        if (x <= xl) return ba - x + (alpha / 2) * (x - xu)**2;
        // x >= xl:
        uint256 rl = 1 - alpha * (xl - xu);
        return rl * (ya - x);
    }

    function computeLowerRedemptionThreshold(
        uint256 ba,
        uint256 ya,
        uint256 alpha,
        uint256 xu
    ) internal pure returns (uint256) {
        if (ba / ya >= 1) return ya;
        uint256 yaxu = ya - xu;
        return ya - (yaxu * yaxu - (2 / alpha) * (ya - ba)).sqrt();
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
        uint256 xuMax = stableRedeemThresholdUpperBound * ya;
        if (alpha * delta <= (targetUtilizationCeiling * targetUtilizationCeiling) / 2)
            xu = ya - ((2 * delta) / alpha).sqrt();
        else xu = ya - delta / targetUtilizationCeiling - targetUtilizationCeiling / (2 * alpha);
        return xuMax < xu ? xuMax : xu;
    }

    function compute_reserve(
        uint256 x,
        uint256 ba,
        uint256 ya,
        uint256 decaySlopeLowerBound,
        uint256 targetUtilizationCeiling,
        uint256 stableRedeemThresholdUpperBound
    ) internal pure returns (uint256) {
        if (ba / ya > 1) return ba - x;
        if (ba / ya <= decaySlopeLowerBound) return ba - (ba / ya) * x;

        uint256 alpha = computeSlope(ba, ya, decaySlopeLowerBound);
        uint256 xu = computeUpperRedemptionThreshold(
            ba,
            ya,
            alpha,
            targetUtilizationCeiling,
            stableRedeemThresholdUpperBound
        );
        uint256 xl = computeLowerRedemptionThreshold(ba, ya, alpha, xu);
        return computeFixedReserve(x, ba, ya, alpha, xu, xl);
    }

    function computeRelativeReserve(
        uint256 xu,
        uint256 ya,
        Params memory params
    ) internal pure returns (uint256) {
        uint256 alpha = params.decaySlopeLowerBound / ya;
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
        uint256 target_usage = ONE - params.targetReserveRatioFloor;
        if (ONE - alpha * yz >= params.targetReserveRatioFloor) return ya - (alpha / 2) * yz * yz;
        return ya - target_usage * yz + (target_usage**2 / 2) * params.decaySlopeLowerBound;
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
            params.stableRedeemThresholdUpperBound,
            params.decaySlopeLowerBound
        );

        uint256 targetUtilizationCeiling = ONE - params.targetReserveRatioFloor;
        derived.reserveHighLowThreshold =
            ONE -
            ((targetUtilizationCeiling * targetUtilizationCeiling) / 2) *
            params.decaySlopeLowerBound;

        derived.upperBoundRedemptionThreshold = computeUpperRedemptionThreshold(
            derived.reserveHighLowThreshold,
            ONE,
            params.decaySlopeLowerBound,
            targetUtilizationCeiling,
            params.stableRedeemThresholdUpperBound
        );

        derived.slopeThreshold = computeSlope(
            (ONE + params.targetReserveRatioFloor) / 2,
            ONE,
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
        if (ba / ya > 1) return ba - x;

        if (ba / ya <= params.decaySlopeLowerBound) return ba - (ba / ya) * x;

        uint256 alpha = computeSlope(ba, ya, params.decaySlopeLowerBound);
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
        uint256 scaledReserve,
        uint256 scaledRedemption,
        Params memory params,
        DerivedParams memory derived
    ) internal pure returns (bool) {
        return
            scaledReserve >=
            computeFixedReserve(
                scaledRedemption,
                derived.reserveValueThresholdFirstRegion,
                ONE,
                derived.slopeThreshold,
                params.stableRedeemThresholdUpperBound,
                derived.lowerRedemptionThreshold
            );
    }

    function isInSecondRegion(
        uint256 scaledReserve,
        uint256 scaledRedemption,
        DerivedParams memory derived
    ) internal pure returns (bool) {
        return
            scaledReserve >=
            computeFixedReserve(
                scaledRedemption,
                derived.reserveValueThresholdSecondRegion,
                ONE,
                derived.slopeThreshold,
                derived.upperBoundRedemptionThreshold,
                ONE
            );
    }

    function isInSecondSubcase(
        uint256 scaledReserve,
        uint256 scaled_redemption,
        uint256 decaySlopeLowerBound,
        DerivedParams memory derived
    ) internal pure returns (bool) {
        return
            scaledReserve >=
            computeFixedReserve(
                scaled_redemption,
                derived.reserveHighLowThreshold,
                ONE,
                decaySlopeLowerBound,
                derived.upperBoundRedemptionThreshold,
                ONE
            );
    }

    function isInHighSubcase(
        uint256 scaled_reserve,
        uint256 scaled_redemption,
        DerivedParams memory derived
    ) internal pure returns (bool) {
        return
            scaled_reserve >=
            computeFixedReserve(
                scaled_redemption,
                derived.reserveHighLowThreshold,
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
        uint256 alphaLow = params.decaySlopeLowerBound;
        uint256 thetha = ONE - params.targetReserveRatioFloor;

        if (
            isInFirstRegion(scaledState.reserveValue, scaledState.redemptionLevel, params, derived)
        ) {
            // case I
            if (scaledState.redemptionLevel <= params.stableRedeemThresholdUpperBound)
                return Region.CASE_i;
            if (scaledState.redemptionLevel <= derived.lowerRedemptionThreshold)
                return Region.CASE_I_ii;
            return Region.CASE_I_iii;
        }

        if (isInSecondRegion(scaledState.reserveValue, scaledState.totalGyroSupply, derived)) {
            // case II
            if (
                isInSecondSubcase(
                    scaledState.reserveValue,
                    scaledState.totalGyroSupply,
                    alphaLow,
                    derived
                )
            ) {
                // case h
                if (
                    scaledState.totalGyroSupply - scaledState.reserveValue <=
                    (alphaLow / 2) * scaledState.totalGyroSupply**2
                ) return Region.CASE_i;
                return Region.CASE_II_H;
            }

            if (
                scaledState.reserveValue -
                    params.targetReserveRatioFloor *
                    scaledState.totalGyroSupply >=
                (thetha**2) / (2 * alphaLow)
            ) return Region.CASE_i;
            return Region.CASE_II_L;
        }

        if (isInHighSubcase(scaledState.reserveValue, scaledState.totalGyroSupply, derived))
            return Region.CASE_III_H;

        return Region.CASE_III_L;
    }

    function computeNextReserveValue(
        State memory scaledState,
        Params memory params,
        DerivedParams memory derived
    ) internal pure returns (uint256) {
        uint256 ya = ONE;
        uint256 reserveRatio = scaledState.reserveValue / scaledState.totalGyroSupply;
        Region region = computeNextReserveValueRegion(scaledState, params, derived);

        uint256 usedRatio = ONE - reserveRatio;
        uint256 thetha = ONE - params.targetReserveRatioFloor;

        if (region == Region.CASE_i) return scaledState.reserveValue + scaledState.redemptionLevel;

        if (region == Region.CASE_I_ii)
            return (scaledState.reserveValue +
                scaledState.redemptionLevel -
                (params.decaySlopeLowerBound *
                    (scaledState.redemptionLevel - params.stableRedeemThresholdUpperBound)**2) /
                2);

        if (region == Region.CASE_I_iii)
            return
                ya -
                (ya - params.stableRedeemThresholdUpperBound) *
                usedRatio +
                usedRatio**2 /
                (2 * params.decaySlopeLowerBound);

        if (region == Region.CASE_II_H) {
            uint256 delta = params.decaySlopeLowerBound *
                (usedRatio / params.decaySlopeLowerBound + scaledState.totalGyroSupply / 2)**2;
            return scaledState.totalGyroSupply - delta;
        }

        if (region == Region.CASE_II_L) {
            uint256 p = usedRatio *
                (usedRatio / (2 * params.decaySlopeLowerBound) + scaledState.totalGyroSupply);
            uint256 d = usedRatio**2 *
                2 *
                (scaledState.reserveValue - params.targetReserveRatioFloor);
            return scaledState.totalGyroSupply - p + d.sqrt();
        }

        if (region == Region.CASE_III_H) {
            uint256 delta = (scaledState.totalGyroSupply - scaledState.reserveValue) /
                (ONE - (scaledState.redemptionLevel**2 / ya**2));
            return ya - delta;
        }

        if (region == Region.CASE_III_L) {
            uint256 p = (scaledState.totalGyroSupply - scaledState.reserveValue + thetha * ya) / 2;
            uint256 q = (scaledState.totalGyroSupply - scaledState.reserveValue) *
                thetha *
                ya +
                (thetha**2 * scaledState.redemptionLevel**2) /
                4;
            uint256 delta = p - (p**2 - q).sqrt();
            return ya - delta;
        }

        revert("unknown region");
    }

    function computeRedeemAmount(
        State memory state,
        Params memory params,
        DerivedParams memory derived,
        uint256 amount
    ) internal pure returns (uint256) {
        uint256 reserveRatio = state.reserveValue / state.totalGyroSupply;
        if (reserveRatio >= ONE) return amount;
        if (reserveRatio <= params.targetReserveRatioFloor) return reserveRatio * amount;

        State memory scaledState;
        uint256 ya = state.totalGyroSupply + state.redemptionLevel;

        scaledState.redemptionLevel = state.redemptionLevel / ya;
        scaledState.reserveValue = state.reserveValue / ya;
        scaledState.totalGyroSupply = state.totalGyroSupply / ya;

        uint256 normalizedReserveValue = computeNextReserveValue(scaledState, params, derived);
        uint256 reserveValue = normalizedReserveValue / ya;

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
