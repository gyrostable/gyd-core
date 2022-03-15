// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../../libraries/LogExpMath.sol";
import "../../libraries/FixedPoint.sol";
import "../../libraries/Flow.sol";
import "../../interfaces/IPAMM.sol";
import "./../auth/Governable.sol";

/// @notice Implements the primary AMM pricing mechanism
contract PrimaryAMMV1Path is Ownable, Governable {
    using LogExpMath for uint256;
    using FixedPoint for uint256;

    uint256 constant ONE = 1e18;
    uint256 constant TWO = 2e18;
    uint256 constant ANCHOR = ONE;

    /// @notice this event is emitted when the system parameters are updated
    event SystemParamsUpdated(uint64 alphaBar, uint64 xuBar, uint64 thetaBar, uint64 outflowMemory);

    // NB gas optimization, don't need to use uint64
    struct Params {
        uint64 alphaBar; // ᾱ ∊ [0,1]
        uint64 xuBar; // x̄_U ∊ [0,1]
        uint64 thetaBar; // θ̄ ∊ [0,1]
        uint64 outflowMemory; // this is [0,1]
    }

    enum Region {
        CASE_i,
        CASE_I_ii,
        CASE_I_iii,
        CASE_II_H,
        CASE_II_L,
        CASE_III_H,
        CASE_III_L
    }

    // NB: potential gas optimization by only storing redemptionLevel
    // NB: if lastSeenBlock is the same as the current block, then can bypass all of the Oracle
    // infrastructure, saving on gas costs
    // NB: don't need many decimals for the outflow paramters, can optimize gas by packing these together
    struct State {
        uint256 redemptionLevel; // x
        uint256 reserveValue; // b
        uint256 totalGyroSupply; // y
        uint256 lastSeenBlock;
    }

    struct DerivedParams {
        uint256 baThresholdRegionI; // b_a^{I/II}
        uint256 baThresholdRegionII; // b_a^{II/III}
        uint256 xlThresholdAtThresholdI; // x_L^{I/II}
        uint256 xlThresholdAtThresholdII; // x_L^{II/III}
        uint256 baThresholdIIHL; // ba^{h/l}
        uint256 baThresholdIIIHL; // ba^{H/L}
        uint256 xuThresholdIIHL; // x_U^{h/l}
        uint256 xlThresholdIIHL; // x_L^{h/l}
        uint256 alphaThresholdIIIHL; // α^{H/L}
        uint256 xlThresholdIIIHL; // x_L^{H/L}
    }

    /// @notice parameters of the primary AMM
    Params public systemParams;

    /// @notice current state of the primary AMM
    State public systemState;

    /// @notice Initializes the PAAM with the given system parameters
    constructor(Params memory params) {
        systemParams = params;
    }

    function setSystemParams(Params memory params) external governanceOnly {
        systemParams = params;
        emit SystemParamsUpdated(
            params.alphaBar,
            params.xuBar,
            params.thetaBar,
            params.outflowMemory
        );
    }

    /// Helpers to compute various parameters

    /// @dev Proposition 3 (section 3) of the paper
    function computeAlphaHat(
        uint256 ba,
        uint256 ya,
        uint256 thetaBar,
        uint256 alphaBar
    ) internal pure returns (uint256) {
        uint256 ra = ba.divDown(ya);
        uint256 alphaMin = alphaBar.divDown(ya);
        uint256 alphaHat;
        if (ra >= (ONE + thetaBar) / 2) {
            alphaHat = TWO.mulDown(ONE - ra).divDown(ya);
        } else {
            uint256 numerator = (ONE - thetaBar)**2;
            uint256 denominator = ba - thetaBar.mulDown(ya);
            alphaHat = numerator / (denominator * 2);
        }
        return alphaHat.max(alphaMin);
    }

    /// @dev Proposition 1 (section 3) of the paper
    function computeReserveFixedParams(
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

    /// @dev Proposition 2 (section 3) of the paper
    function computeXl(
        uint256 ba,
        uint256 ya,
        uint256 alpha,
        uint256 xu
    ) internal pure returns (uint256) {
        if (ba >= ya) {
            return ya;
        }
        uint256 left = (ya - xu).squareUp();
        uint256 right = (TWO * (ya - ba)) / alpha;
        uint256 rh = left > right ? (left - right).sqrt() : 0;
        return ya - rh;
    }

    /// @dev Proposition 4 (section 3) of the paper
    function computeXuHat(
        uint256 ba,
        uint256 ya,
        uint256 alpha,
        uint256 xuBar,
        uint256 theta
    ) internal pure returns (uint256) {
        uint256 delta = ya - ba;
        uint256 xuMax = xuBar.mulDown(ya);
        uint256 xu;
        if (alpha.mulDown(delta) <= theta**2 / TWO) {
            uint256 rh = ((TWO * delta) / alpha);
            xu = rh > ya.squareUp() ? 0 : ya - rh.sqrt();
        } else {
            xu = ya - delta.divDown(theta) - theta.divDown(2 * alpha);
        }

        return xu.min(xuMax);
    }

    /// @dev Lemma 4 (seection 7) of the paper
    function computeBa(uint256 xu, Params memory params) internal pure returns (uint256) {
        require(ONE >= xu, "ya must be greater than xu");
        uint256 alpha = params.alphaBar;

        uint256 yz = ANCHOR - xu;
        if (ONE - alpha.mulDown(yz) >= params.thetaBar)
            return ANCHOR - (alpha * yz.squareDown()) / TWO;
        uint256 theta = ONE - params.thetaBar;
        return ANCHOR - theta.mulDown(yz) + theta**2 / (2 * alpha);
    }

    /// @dev Algorithm 1 (section 7) of the paper
    function createDerivedParams(Params memory params)
        internal
        pure
        returns (DerivedParams memory)
    {
        DerivedParams memory derived;

        derived.baThresholdRegionI = computeBa(params.xuBar, params);
        derived.baThresholdRegionII = computeBa(0, params);

        derived.xlThresholdAtThresholdI = computeXl(
            derived.baThresholdRegionI,
            ONE,
            params.alphaBar,
            params.xuBar
        );
        derived.xlThresholdAtThresholdII = computeXl(
            derived.baThresholdRegionII,
            ONE,
            params.alphaBar,
            0
        );

        uint256 theta = ONE - params.thetaBar;
        derived.baThresholdIIHL = ONE - (theta**2) / (2 * params.alphaBar);

        derived.xuThresholdIIHL = computeXuHat(
            derived.baThresholdIIHL,
            ONE,
            params.alphaBar,
            params.xuBar,
            theta
        );
        derived.xlThresholdIIHL = computeXl(
            derived.baThresholdIIHL,
            ONE,
            params.alphaBar,
            derived.xuThresholdIIHL
        );

        derived.baThresholdIIIHL = (ONE + params.thetaBar) / 2;
        derived.alphaThresholdIIIHL = computeAlphaHat(
            derived.baThresholdIIIHL,
            ONE,
            params.thetaBar,
            params.alphaBar
        );

        derived.xlThresholdIIIHL = computeXl(derived.baThresholdIIIHL, ONE, params.alphaBar, 0);

        return derived;
    }

    function computeReserve(
        uint256 x,
        uint256 ba,
        uint256 ya,
        Params memory params
    ) internal pure returns (uint256) {
        uint256 alpha = computeAlphaHat(ba, ya, params.thetaBar, params.alphaBar);
        uint256 xu = computeXuHat(ba, ya, alpha, params.xuBar, ONE - params.thetaBar);
        uint256 xl = computeXl(ba, ya, alpha, xu);
        return computeReserveFixedParams(x, ba, ya, alpha, xu, xl);
    }

    function isInFirstRegion(
        State memory anchoredState,
        Params memory params,
        DerivedParams memory derived
    ) internal pure returns (bool) {
        return
            anchoredState.reserveValue >=
            computeReserveFixedParams(
                anchoredState.redemptionLevel,
                derived.baThresholdRegionI,
                ONE,
                params.alphaBar,
                params.xuBar,
                derived.xlThresholdAtThresholdI
            );
    }

    function isInSecondRegion(
        State memory anchoredState,
        uint256 alphaBar,
        DerivedParams memory derived
    ) internal pure returns (bool) {
        return
            anchoredState.reserveValue >=
            computeReserveFixedParams(
                anchoredState.redemptionLevel,
                derived.baThresholdRegionII,
                ONE,
                alphaBar,
                0,
                derived.xlThresholdAtThresholdII
            );
    }

    function isInSecondRegionHigh(
        State memory anchoredState,
        uint256 alphaBar,
        DerivedParams memory derived
    ) internal pure returns (bool) {
        return
            anchoredState.reserveValue >=
            computeReserveFixedParams(
                anchoredState.redemptionLevel,
                derived.baThresholdIIHL,
                ONE,
                alphaBar,
                derived.xuThresholdIIHL,
                derived.xlThresholdIIHL
            );
    }

    function isInThirdRegionHigh(State memory anchoredState, DerivedParams memory derived)
        internal
        pure
        returns (bool)
    {
        return
            anchoredState.reserveValue >=
            computeReserveFixedParams(
                anchoredState.redemptionLevel,
                derived.baThresholdIIIHL,
                ONE,
                derived.alphaThresholdIIIHL,
                0,
                derived.xlThresholdIIHL
            );
    }

    function computeReserveValueRegion(
        State memory anchoredState,
        Params memory params,
        DerivedParams memory derived
    ) internal pure returns (Region) {
        if (isInFirstRegion(anchoredState, params, derived)) {
            // case I
            if (anchoredState.redemptionLevel <= params.xuBar) return Region.CASE_i;
            if (anchoredState.redemptionLevel <= derived.xlThresholdAtThresholdI)
                return Region.CASE_I_ii;
            return Region.CASE_I_iii;
        }

        if (isInSecondRegion(anchoredState, params.alphaBar, derived)) {
            // case II
            if (isInSecondRegionHigh(anchoredState, params.alphaBar, derived)) {
                // case II_h
                if (
                    anchoredState.totalGyroSupply - anchoredState.reserveValue <=
                    (anchoredState.totalGyroSupply.squareDown() * params.alphaBar) / TWO
                ) return Region.CASE_i;
                return Region.CASE_II_H;
            }

            uint256 theta = ONE - params.thetaBar;
            if (
                anchoredState.reserveValue -
                    uint256(params.thetaBar).mulDown(anchoredState.totalGyroSupply) >=
                theta**2 / (2 * params.alphaBar)
            ) return Region.CASE_i;
            return Region.CASE_II_L;
        }

        if (isInThirdRegionHigh(anchoredState, derived)) {
            return Region.CASE_III_H;
        }

        return Region.CASE_III_L;
    }

    struct NextReserveValueVars {
        uint256 ya;
        uint256 r;
        Region region;
        uint256 u;
        uint256 theta;
    }

    function computeAnchoredReserveValue(
        State memory anchoredState,
        Params memory params,
        DerivedParams memory derived
    ) internal pure returns (uint256) {
        NextReserveValueVars memory vars;

        Region region = computeReserveValueRegion(anchoredState, params, derived);

        vars.ya = ONE;
        vars.r = anchoredState.reserveValue.divDown(anchoredState.totalGyroSupply);
        vars.u = ONE - vars.r;
        vars.theta = ONE - params.thetaBar;

        if (region == Region.CASE_i) {
            return anchoredState.reserveValue + anchoredState.redemptionLevel;
        }

        if (region == Region.CASE_I_ii) {
            uint256 xDiff = anchoredState.redemptionLevel - params.xuBar;
            return (anchoredState.reserveValue +
                anchoredState.redemptionLevel -
                (params.alphaBar * xDiff.squareDown()) /
                TWO);
        }

        if (region == Region.CASE_I_iii)
            return
                vars.ya -
                (vars.ya - params.xuBar).mulDown(vars.u) +
                (vars.u**2 / (2 * params.alphaBar));

        if (region == Region.CASE_II_H) {
            uint256 delta = (params.alphaBar *
                (vars.u.divDown(params.alphaBar) + (anchoredState.totalGyroSupply / 2))
                    .squareDown()) / TWO;
            return vars.ya - delta;
        }

        if (region == Region.CASE_II_L) {
            uint256 p = vars.theta.mulDown(
                vars.theta.divDown(2 * params.alphaBar) + anchoredState.totalGyroSupply
            );
            uint256 d = 2 *
                (vars.theta**2 / params.alphaBar).mulDown(
                    anchoredState.reserveValue -
                        anchoredState.totalGyroSupply.mulDown(params.thetaBar)
                );
            return vars.ya + d.sqrt() - p;
        }

        if (region == Region.CASE_III_H) {
            uint256 delta = (anchoredState.totalGyroSupply - anchoredState.reserveValue).divDown(
                (ONE - anchoredState.redemptionLevel.squareDown())
            );
            return vars.ya - delta;
        }

        if (region == Region.CASE_III_L) {
            uint256 p = (anchoredState.totalGyroSupply - anchoredState.reserveValue + vars.theta) /
                2;
            uint256 q = (anchoredState.totalGyroSupply - anchoredState.reserveValue).mulDown(
                vars.theta
            ) + vars.theta.squareDown().mulDown(anchoredState.redemptionLevel.squareDown()) / 4;
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

        if (nav <= params.thetaBar) {
            return nav.mulDown(amount);
        }

        State memory anchoredState;
        uint256 ya = state.totalGyroSupply + state.redemptionLevel;

        anchoredState.redemptionLevel = state.redemptionLevel.divDown(ya);
        anchoredState.reserveValue = state.reserveValue.divDown(ya);
        anchoredState.totalGyroSupply = state.totalGyroSupply.divDown(ya);

        uint256 anchoredReserveValue = computeAnchoredReserveValue(anchoredState, params, derived);
        uint256 reserveValue = anchoredReserveValue.mulDown(ya);

        uint256 nextReserveValue = computeReserve(
            state.redemptionLevel + amount,
            reserveValue,
            ya,
            params
        );
        // we are redeeming so the next reserve value must be smaller than the current one
        return state.reserveValue - nextReserveValue;
    }

    /// @notice Returns the USD value to mint given an ammount of Gyro dollars
    function computeMintAmount(uint256 usdAmount, uint256) external pure returns (uint256) {
        return usdAmount;
    }

    /// @notice Records and returns the USD value to mint given an ammount of Gyro dollars
    function mint(uint256 usdAmount, uint256) external onlyOwner returns (uint256) {
        State storage state = systemState;
        state.totalGyroSupply += usdAmount;
        state.reserveValue += usdAmount;
        return usdAmount;
    }

    /// @notice Computes the USD value to redeem given an ammount of Gyro dollars
    function computeRedeemAmount(uint256 gydAmount, uint256 reserveUSDValue)
        external
        view
        returns (uint256)
    {
        if (gydAmount == 0) return 0;
        Params memory params = systemParams;
        DerivedParams memory derived = createDerivedParams(params);
        State memory currentState = computeStartingRedeemState(reserveUSDValue, params);
        return computeRedeemAmount(currentState, params, derived, gydAmount);
    }

    function computeStartingRedeemState(uint256 reserveUSDValue, Params memory params)
        internal
        view
        returns (State memory currentState)
    {
        currentState = systemState;
        currentState.reserveValue = reserveUSDValue;
        uint256 currentBlock = block.number;
        currentState.redemptionLevel = Flow.updateFlow(
            currentState.redemptionLevel,
            currentBlock,
            currentState.lastSeenBlock,
            params.outflowMemory
        );
        currentState.lastSeenBlock = currentBlock;
    }

    /// @notice Computes and records the USD value to redeem given an ammount of Gyro dollars
    // NB reserveValue does not need to be stored as part of state - could be passed around
    function redeem(uint256 gydAmount, uint256 reserveUSDValue)
        internal
        onlyOwner
        returns (uint256)
    {
        if (gydAmount == 0) return 0;
        Params memory params = systemParams;
        State memory currentState = computeStartingRedeemState(reserveUSDValue, params);
        DerivedParams memory derived = createDerivedParams(params);
        uint256 redeemAmount = computeRedeemAmount(currentState, params, derived, gydAmount);
        currentState.redemptionLevel += gydAmount;
        currentState.totalGyroSupply -= gydAmount;
        currentState.reserveValue -= redeemAmount;
        systemState = currentState;
        return redeemAmount;
    }
}
