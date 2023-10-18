// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IPAMM.sol";
import "../interfaces/IGyroConfig.sol";

import "../libraries/LogExpMath.sol";
import "../libraries/FixedPoint.sol";
import "../libraries/Flow.sol";
import "../libraries/ConfigHelpers.sol";

import "./auth/Governable.sol";

/// @notice Implements the primary AMM pricing mechanism
contract PrimaryAMMV1 is IPAMM, Governable {
    using LogExpMath for uint256;
    using FixedPoint for uint256;
    using ConfigHelpers for IGyroConfig;

    IGyroConfig public immutable gyroConfig;

    /// @dev we tolerate underflows due to numerical issues up to 1e10, so 1e-8
    /// given our 1e18 scale
    uint256 internal constant _UNDERFLOW_EPSILON = 1e10;

    uint256 internal constant ONE = 1e18;
    uint256 internal constant TWO = 2e18;
    uint256 internal constant ANCHOR = ONE;

    modifier onlyMotherboard() {
        require(msg.sender == address(gyroConfig.getMotherboard()), Errors.NOT_AUTHORIZED);
        _;
    }

    enum Region {
        CASE_i, // 0
        CASE_I_ii, // 1
        CASE_I_iii, // 2
        CASE_II_H, // 3
        CASE_II_L, // 4
        CASE_III_H, // 5
        CASE_III_L // 6
    }

    struct State {
        uint256 redemptionLevel; // x
        uint256 reserveValue; // b
        uint256 totalGyroSupply; // y
    }

    /** @dev
     * For the `*HL` values, these are only defined if both of the respective regions (on either
     * side of the threshold) exist (and are otherwise 0). To see if this is the case, check the
     * respective `ba*HL` value against `baThresholdRegionI` and `baThresholdRegionII`.
     * Specifically:
     *  - The `*IIHL` values are well-defined iff
     *    `baThresholdRegionI > baThresholdIIHL > baThresholdRegionII`.
     *  - The `*IIIHL` values are well-defined iff `baThresholdRegionII > baThresholdIIIHL`.
     * In constrast, the `*{I,II,III}` values are all always well-defined.
     */
    struct DerivedParams {
        uint256 baThresholdRegionI; // b_a^{I/II}
        uint256 baThresholdRegionII; // b_a^{II/III}
        // SOMEDAY knowing that these are at their respective thresholds, the xl and xu calculations could be further simplified.
        uint256 xlThresholdAtThresholdI; // x_L^{I/II}
        uint256 xlThresholdAtThresholdII; // x_L^{II/III}
        uint256 baThresholdIIHL; // ba^{h/l}
        uint256 baThresholdIIIHL; // ba^{H/L}
        uint256 xuThresholdIIHL; // x_U^{h/l}
    }

    /// @notice parameters of the primary AMM
    Params internal _systemParams;

    /// @notice current redemption level of the primary AMM
    uint256 public redemptionLevel;

    /// @notice the last block at which a redemption occured
    uint256 public lastRedemptionBlock;

    /// @notice Initializes the PAMM with the given system parameters
    constructor(
        address _governor,
        address _gyroConfig,
        Params memory params
    ) Governable(_governor) {
        require(_gyroConfig != address(0), Errors.INVALID_ARGUMENT);
        gyroConfig = IGyroConfig(_gyroConfig);
        _systemParams = params;
    }

    /// @inheritdoc IPAMM
    function systemParams() external view returns (Params memory) {
        return _systemParams;
    }

    /// @inheritdoc IPAMM
    function setSystemParams(Params memory params) external governanceOnly {
        _systemParams = params;

        // NOTE: this is not strictly needed but ensures that the given
        // parameters allow to compute the derived parameters without underflowing
        createDerivedParams(params);

        emit SystemParamsUpdated(
            params.alphaBar,
            params.xuBar,
            params.thetaBar,
            params.outflowMemory
        );
    }

    /// Helpers to compute various parameters

    /// @dev Proposition 3 (section 3) of the paper
    function computeAlpha(
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
            uint256 pos = ba + (alpha * (x - xu).squareDown()) / TWO;
            if (pos >= x) return pos - x;
            else {
                require(pos + _UNDERFLOW_EPSILON.mulDown(ya) >= x, Errors.SUB_OVERFLOW);
                return 0;
            }
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
        require(ba < ya, Errors.INVALID_ARGUMENT);
        uint256 left = (ya - xu).squareUp();
        uint256 right = (TWO * (ya - ba)) / alpha;
        if (left >= right) {
            return ya - (left - right).sqrt();
        } else {
            return ya;
        }
    }

    /// @dev Proposition 4 (section 3) of the paper
    function computeXu(
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
            uint256 rhSqrt = rh.sqrt();
            xu = rhSqrt >= ya ? 0 : ya - rhSqrt;
        } else {
            uint256 subtracted = delta.divDown(theta) + theta.divDown(2 * alpha);
            xu = subtracted >= ya ? 0 : ya - subtracted;
        }

        return xu.min(xuMax);
    }

    /// @dev Lemma 4 (seection 7) of the paper
    function computeBa(uint256 xu, Params memory params) internal pure returns (uint256) {
        require(ONE >= xu, "ya must be greater than xu");
        uint256 alpha = params.alphaBar;

        uint256 yz = ANCHOR - xu;
        if (ONE >= params.thetaBar + alpha.mulDown(yz))
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

        {
            uint256 subtrahend = (theta**2) / (2 * uint256(params.alphaBar));
            derived.baThresholdIIHL = ONE >= subtrahend ? ONE - subtrahend : 0;
        }

        if (
            derived.baThresholdRegionI > derived.baThresholdIIHL &&
            derived.baThresholdIIHL > derived.baThresholdRegionII
        ) {
            derived.xuThresholdIIHL = computeXu(
                derived.baThresholdIIHL,
                ONE,
                params.alphaBar,
                params.xuBar,
                theta
            );
        }

        derived.baThresholdIIIHL = (ONE + params.thetaBar) / 2;

        return derived;
    }

    function computeReserve(
        uint256 x,
        uint256 ba,
        uint256 ya,
        Params memory params
    ) internal pure returns (uint256) {
        uint256 alpha = computeAlpha(ba, ya, params.thetaBar, params.alphaBar);
        uint256 xu = computeXu(ba, ya, alpha, params.xuBar, ONE - params.thetaBar);
        uint256 xl = computeXl(ba, ya, alpha, xu);
        return computeReserveFixedParams(x, ba, ya, alpha, xu, xl);
    }

    function isInFirstRegion(
        State memory normalizedState,
        Params memory params,
        DerivedParams memory derived
    ) internal pure returns (bool) {
        return
            normalizedState.reserveValue >=
            computeReserveFixedParams(
                normalizedState.redemptionLevel,
                derived.baThresholdRegionI,
                ONE,
                params.alphaBar,
                params.xuBar,
                derived.xlThresholdAtThresholdI
            );
    }

    function isInSecondRegion(
        State memory normalizedState,
        uint256 alphaBar,
        DerivedParams memory derived
    ) internal pure returns (bool) {
        return
            normalizedState.reserveValue >=
            computeReserveFixedParams(
                normalizedState.redemptionLevel,
                derived.baThresholdRegionII,
                ONE,
                alphaBar,
                0,
                derived.xlThresholdAtThresholdII
            );
    }

    function isInSecondRegionHigh(
        State memory normalizedState,
        uint256 alphaBar,
        DerivedParams memory derived
    ) internal pure returns (bool) {
        if (derived.baThresholdIIHL <= derived.baThresholdRegionII) return true;
        if (derived.baThresholdIIHL > derived.baThresholdRegionI) return false;
        return
            normalizedState.reserveValue >=
            computeReserveFixedParams(
                normalizedState.redemptionLevel,
                derived.baThresholdIIHL,
                ONE,
                alphaBar,
                derived.xuThresholdIIHL,
                ONE
            );
    }

    function isInThirdRegionHigh(
        State memory normalizedState,
        Params memory params,
        DerivedParams memory derived
    ) internal pure returns (bool) {
        if (derived.baThresholdIIIHL > derived.baThresholdRegionII) return false;
        return
            normalizedState.reserveValue >=
            computeReserveFixedParams(
                normalizedState.redemptionLevel,
                derived.baThresholdIIIHL,
                ONE,
                ONE - params.thetaBar,
                0,
                ONE
            );
    }

    function computeReserveValueRegion(
        State memory normalizedState,
        Params memory params,
        DerivedParams memory derived
    ) internal pure returns (Region) {
        if (isInFirstRegion(normalizedState, params, derived)) {
            // case I
            if (normalizedState.redemptionLevel <= params.xuBar) return Region.CASE_i;

            uint256 lhs = normalizedState.reserveValue.divDown(normalizedState.totalGyroSupply) +
                uint256(params.alphaBar).mulDown(normalizedState.redemptionLevel - params.xuBar);
            uint256 rhs = ONE;
            if (lhs <= rhs) return Region.CASE_I_ii;
            return Region.CASE_I_iii;
        }

        if (isInSecondRegion(normalizedState, params.alphaBar, derived)) {
            // case II
            if (isInSecondRegionHigh(normalizedState, params.alphaBar, derived)) {
                // case II_h
                if (
                    normalizedState.totalGyroSupply - normalizedState.reserveValue <=
                    (normalizedState.totalGyroSupply.squareDown() * params.alphaBar) / TWO
                ) return Region.CASE_i;
                return Region.CASE_II_H;
            }

            uint256 theta = ONE - params.thetaBar;
            if (
                normalizedState.reserveValue -
                    uint256(params.thetaBar).mulDown(normalizedState.totalGyroSupply) >=
                theta**2 / (2 * uint256(params.alphaBar))
            ) return Region.CASE_i;
            return Region.CASE_II_L;
        }

        if (isInThirdRegionHigh(normalizedState, params, derived)) {
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
        State memory normalizedState,
        Params memory params,
        DerivedParams memory derived
    ) internal pure returns (uint256) {
        NextReserveValueVars memory vars;

        Region region = computeReserveValueRegion(normalizedState, params, derived);

        vars.ya = ONE;
        vars.r = normalizedState.reserveValue.divDown(normalizedState.totalGyroSupply);
        vars.u = ONE - vars.r;
        vars.theta = ONE - params.thetaBar;

        if (region == Region.CASE_i) {
            return normalizedState.reserveValue + normalizedState.redemptionLevel;
        }

        if (region == Region.CASE_I_ii) {
            uint256 xDiff = normalizedState.redemptionLevel - params.xuBar;
            return (normalizedState.reserveValue +
                normalizedState.redemptionLevel -
                (params.alphaBar * xDiff.squareDown()) /
                TWO);
        }

        if (region == Region.CASE_I_iii)
            return
                vars.ya -
                (vars.ya - params.xuBar).mulDown(vars.u) +
                (vars.u**2 / (2 * uint256(params.alphaBar)));

        if (region == Region.CASE_II_H) {
            uint256 delta = (params.alphaBar *
                (vars.u.divDown(params.alphaBar) + (normalizedState.totalGyroSupply / 2))
                    .squareDown()) / TWO;
            return vars.ya - delta;
        }

        if (region == Region.CASE_II_L) {
            uint256 p = vars.theta.mulDown(
                vars.theta.divDown(2 * uint256(params.alphaBar)) + normalizedState.totalGyroSupply
            );
            uint256 d = 2 *
                (vars.theta**2 / params.alphaBar).mulDown(
                    normalizedState.reserveValue -
                        normalizedState.totalGyroSupply.mulDown(params.thetaBar)
                );
            return vars.ya + d.sqrt() - p;
        }

        if (region == Region.CASE_III_H) {
            uint256 delta = (normalizedState.totalGyroSupply - normalizedState.reserveValue)
                .divDown((ONE - normalizedState.redemptionLevel.squareDown()));
            return vars.ya - delta;
        }

        if (region == Region.CASE_III_L) {
            uint256 p = (normalizedState.totalGyroSupply -
                normalizedState.reserveValue +
                vars.theta) / 2;
            uint256 q = (normalizedState.totalGyroSupply - normalizedState.reserveValue).mulDown(
                vars.theta
            ) + vars.theta.squareDown().mulDown(normalizedState.redemptionLevel.squareDown()) / 4;
            uint256 delta = p - (p.squareDown() - q).sqrt();
            return vars.ya - delta;
        }

        revert("unknown region");
    }

    /// @dev redeemDiscountRatio is expected to be a small value along the lines of 1%
    /// this means that the first condition should always be true unless if the system
    /// is in a extreme state
    function _computeDiscountedReserveValue(uint256 reserveValue, uint256 totalGyroSupply)
        internal
        view
        returns (uint256)
    {
        uint256 redeemDiscountRatio = gyroConfig.getUint(ConfigKeys.REDEEM_DISCOUNT_RATIO);

        if (reserveValue > 2 * redeemDiscountRatio.mulDown(totalGyroSupply)) {
            uint256 discounted = reserveValue - redeemDiscountRatio.mulDown(totalGyroSupply);
            return discounted.min(totalGyroSupply);
        }

        return reserveValue;
    }

    function computeRedeemAmount(
        State memory state,
        Params memory params,
        DerivedParams memory derived,
        uint256 amount
    ) internal view returns (uint256) {
        State memory normalizedState;
        uint256 ya = state.totalGyroSupply + state.redemptionLevel;

        state.reserveValue = _computeDiscountedReserveValue(
            state.reserveValue,
            state.totalGyroSupply
        );

        normalizedState.redemptionLevel = state.redemptionLevel.divDown(ya);
        normalizedState.reserveValue = state.reserveValue.divDown(ya);
        normalizedState.totalGyroSupply = state.totalGyroSupply.divDown(ya);

        uint256 normalizedNav = normalizedState.reserveValue.divDown(
            normalizedState.totalGyroSupply
        );

        if (normalizedNav >= ONE) {
            return amount;
        }

        if (normalizedNav <= params.thetaBar) {
            uint256 nav = state.reserveValue.divDown(state.totalGyroSupply);
            return nav.mulDown(amount);
        }

        uint256 normalizedAnchoredReserveValue = computeAnchoredReserveValue(
            normalizedState,
            params,
            derived
        );
        uint256 anchoredReserveValue = normalizedAnchoredReserveValue.mulDown(ya);

        uint256 nextReserveValue = computeReserve(
            state.redemptionLevel + amount,
            anchoredReserveValue,
            ya,
            params
        );
        // we are redeeming so the next reserve value must be smaller than the current one
        uint256 redeemAmount = state.reserveValue - nextReserveValue;

        // Defensive programming. The following conditions could only occur due to numerical inaccuracy in extreme situations.
        if (redeemAmount > amount) redeemAmount = amount;
        if (redeemAmount > state.totalGyroSupply) redeemAmount = state.totalGyroSupply;

        return redeemAmount;
    }

    function getNormalizedAnchoredReserveValue(uint256 reserveUSDValue)
        external
        view
        returns (uint256)
    {
        // This is copied & adjusted from the two variants of computeRedeemAmount(), but we exit earlier.
        Params memory params = _systemParams;
        DerivedParams memory derived = createDerivedParams(params);
        State memory state = computeStartingRedeemState(reserveUSDValue, params);

        State memory normalizedState;
        uint256 ya = state.totalGyroSupply + state.redemptionLevel;

        state.reserveValue = _computeDiscountedReserveValue(
            state.reserveValue,
            state.totalGyroSupply
        );

        normalizedState.redemptionLevel = state.redemptionLevel.divDown(ya);
        normalizedState.reserveValue = state.reserveValue.divDown(ya);
        normalizedState.totalGyroSupply = state.totalGyroSupply.divDown(ya);

        uint256 normalizedNav = normalizedState.reserveValue.divDown(
            normalizedState.totalGyroSupply
        );

        if (normalizedNav >= ONE) {
            return ONE;
        }

        if (normalizedNav <= params.thetaBar) {
            uint256 nav = state.reserveValue.divDown(state.totalGyroSupply);
            return nav;
        }

        return computeAnchoredReserveValue(normalizedState, params, derived);
    }

    /// @notice Returns the USD value to mint given an ammount of Gyro dollars
    function computeMintAmount(uint256 usdAmount, uint256) external pure returns (uint256) {
        return usdAmount;
    }

    /// @notice Records and returns the USD value to mint given an ammount of Gyro dollars
    function mint(uint256 usdAmount, uint256) external view onlyMotherboard returns (uint256) {
        return usdAmount;
    }

    /// @notice Computes the USD value to redeem given an ammount of Gyro dollars
    function computeRedeemAmount(uint256 gydAmount, uint256 reserveUSDValue)
        external
        view
        returns (uint256)
    {
        if (gydAmount == 0) return 0;
        Params memory params = _systemParams;
        DerivedParams memory derived = createDerivedParams(params);
        State memory currentState = computeStartingRedeemState(reserveUSDValue, params);
        return computeRedeemAmount(currentState, params, derived, gydAmount);
    }

    function computeRedeemAmountFromState(
        uint256 gydAmount,
        uint256 reserveUSDValue,
        uint256 redemptionLevel_,
        uint256 totalGyroSupply
    ) external view returns (uint256) {
        if (gydAmount == 0) return 0;
        Params memory params = _systemParams;
        DerivedParams memory derived = createDerivedParams(params);
        State memory state = State({
            reserveValue: reserveUSDValue,
            redemptionLevel: redemptionLevel_,
            totalGyroSupply: totalGyroSupply
        });
        return computeRedeemAmount(state, params, derived, gydAmount);
    }

    function getRedemptionLevel() external view returns (uint256) {
        return
            Flow.updateFlow(
                redemptionLevel,
                block.number,
                lastRedemptionBlock,
                _systemParams.outflowMemory
            );
    }

    function computeStartingRedeemState(uint256 reserveUSDValue, Params memory params)
        internal
        view
        returns (State memory currentState)
    {
        return
            State({
                reserveValue: reserveUSDValue,
                redemptionLevel: Flow.updateFlow(
                    redemptionLevel,
                    block.number,
                    lastRedemptionBlock,
                    params.outflowMemory
                ),
                totalGyroSupply: _getGyroSupply()
            });
    }

    /// @notice Computes and records the USD value to redeem given an ammount of Gyro dollars
    // NB reserveValue does not need to be stored as part of state - could be passed around
    function redeem(uint256 gydAmount, uint256 reserveUSDValue)
        public
        onlyMotherboard
        returns (uint256)
    {
        if (gydAmount == 0) return 0;
        Params memory params = _systemParams;
        State memory currentState = computeStartingRedeemState(reserveUSDValue, params);
        DerivedParams memory derived = createDerivedParams(params);
        uint256 redeemAmount = computeRedeemAmount(currentState, params, derived, gydAmount);

        redemptionLevel = currentState.redemptionLevel + gydAmount;
        lastRedemptionBlock = block.number;

        return redeemAmount;
    }

    function _getGyroSupply() internal view virtual returns (uint256) {
        return gyroConfig.getMotherboard().mintedSupply();
    }
}
