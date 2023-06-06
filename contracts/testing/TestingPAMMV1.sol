// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.

pragma solidity ^0.8.4;

import "../PrimaryAMMV1.sol";
// import "forge-std/console.sol";

contract TestingPAMMV1 is PrimaryAMMV1 {
    using FixedPoint for uint256;

    uint256 internal _gyroSupply;

    constructor(
        address _governor,
        address gyroConfig,
        Params memory params
    ) PrimaryAMMV1(_governor, gyroConfig, params) {}

    /** @dev returns reconstructed Region plus additional values for situations that would be caught *before*
     * region detection even runs:
     * 10 = reserve ratio <= theta_bar
     * 20 = reserve ratio >= 1
     */
    function computeRegion(State calldata normalizedState) external view returns (uint256) {
        DerivedParams memory derived = createDerivedParams(_systemParams);

        uint256 b = computeReserve(
            normalizedState.redemptionLevel,
            normalizedState.reserveValue,
            normalizedState.totalGyroSupply,
            _systemParams
        );
        uint256 y = normalizedState.totalGyroSupply - normalizedState.redemptionLevel;
        State memory state = State({
            redemptionLevel: normalizedState.redemptionLevel,
            reserveValue: b,
            totalGyroSupply: y
        });

        uint256 normalizedNav = state.reserveValue.divDown(state.totalGyroSupply);
        if (normalizedNav >= ONE) {
            return 20;
        }
        if (normalizedNav <= _systemParams.thetaBar) {
            return 10;
        }

        return uint256(computeReserveValueRegion(state, _systemParams, derived));
    }

    /// @dev Perform region reconstruction. Returns the "extended" state flags like computeRegion().
    function reconstructRegion(State calldata state) external view returns (uint256) {
        uint256 normalizedNav = state.reserveValue.divDown(state.totalGyroSupply);
        if (normalizedNav >= ONE) {
            return 20;
        }
        if (normalizedNav <= systemParams.thetaBar) {
            return 10;
        }

        DerivedParams memory derived = createDerivedParams(systemParams);
        return uint256(computeReserveValueRegion(state, systemParams, derived));
    }

    /// @dev like computeRegion() but doesn't reconstruct the region but detects it based on its
    /// knowledge about the anchor point.
    function computeTrueRegion(State calldata normalizedState) external view returns (uint256) {
        uint256 normalizedNav = normalizedState.reserveValue.divDown(normalizedState.totalGyroSupply);
        if (normalizedNav >= ONE) {
            return 20;
        }
        if (normalizedNav <= systemParams.thetaBar) {
            return 10;
        }

        uint256 theta = FixedPoint.ONE - systemParams.thetaBar;

        uint256 ba = normalizedState.reserveValue;  // shorthand
        uint256 ya = normalizedState.totalGyroSupply;  // shorthand
        uint256 x = normalizedState.redemptionLevel;  // shorthand
        uint256 alpha = computeAlpha(ba, ya, systemParams.thetaBar, systemParams.alphaBar);
        uint256 xu = computeXu(ba, ya, alpha, systemParams.xuBar, theta);
        uint256 xl = computeXl(ba, ya, alpha, xu, false);
        if (x <= xu)
            return uint(Region.CASE_i);
        // Now x > xu
        if (xu == systemParams.xuBar) {
            // Case I
            if (x <= xl)
                return uint(Region.CASE_I_ii);
            else
                return uint(Region.CASE_I_iii);
        }

        // Detect case iii. Region detection wouldn't run here, so it doesn't have a Region entry.
        if (x >= xl)
            return 10;

        if (alpha == systemParams.alphaBar) {

            // now region ii.
            if (alpha.mulDown(ya - ba) <= uint(0.5e18).mulDown(theta).mulDown(theta))
                return uint(Region.CASE_II_H);
            else
                return uint(Region.CASE_II_L);
        }
        {
            if (normalizedNav >= (FixedPoint.ONE + systemParams.thetaBar) / 2)
                return uint(Region.CASE_III_H);
            else
                return uint(Region.CASE_III_L);
        }
    }

    // TODO Rename
    function computeReserveValue(State calldata normalizedState) public view returns (uint256) {
        Params memory params = _systemParams;
        DerivedParams memory derived = createDerivedParams(_systemParams);
        uint256 b = computeReserve(
            normalizedState.redemptionLevel,
            normalizedState.reserveValue,
            normalizedState.totalGyroSupply,
            _systemParams
        );
        uint256 y = normalizedState.totalGyroSupply - normalizedState.redemptionLevel;
        State memory state = State({
            redemptionLevel: normalizedState.redemptionLevel,
            reserveValue: b,
            totalGyroSupply: y
        });
        return computeAnchoredReserveValue(state, params, derived);
    }

    function computeReserveValueFromAnchor(State calldata anchoredState) public view returns (uint256) {
        return computeReserve(
            anchoredState.redemptionLevel,
            anchoredState.reserveValue,
            anchoredState.totalGyroSupply,
            systemParams
        );
    }

    /// @dev Reconstruct anchor point from state, then compute the reserve value from there and return.
    /// This should return its input reserve value unless there's a bug.
    function roundTripState(State calldata state) public view returns (uint256 reconstructedReserveValue) {
        DerivedParams memory derived = createDerivedParams(systemParams);

        State memory normalizedState;
        uint256 ya = state.totalGyroSupply + state.redemptionLevel;

        normalizedState.redemptionLevel = state.redemptionLevel.divDown(ya);
        normalizedState.reserveValue = state.reserveValue.divDown(ya);
        normalizedState.totalGyroSupply = state.totalGyroSupply.divDown(ya);

        uint256 normalizedNav = normalizedState.reserveValue.divDown(
            normalizedState.totalGyroSupply
        );

        if (normalizedNav >= FixedPoint.ONE)
            // Nothing to do here.
            return state.reserveValue;
        if (normalizedNav <= systemParams.thetaBar)
            // Again nothing that can be done.
            return state.reserveValue;

        uint256 normalizedAnchoredReserveValue = computeAnchoredReserveValue(
            normalizedState,
            systemParams,
            derived
        );
        uint256 anchoredReserveValue = normalizedAnchoredReserveValue.mulDown(ya);

        reconstructedReserveValue = computeReserve(state.redemptionLevel, anchoredReserveValue, ya, systemParams);
    }

    // NOTE: needs to not be pure to be able to get transaction information from the frontend
    function computeReserveValueWithGas(State calldata normalizedState)
        external
        view
        returns (uint256)
    {
        return computeReserveValue(normalizedState);
    }

    function testComputeFixedReserve(
        uint256 x,
        uint256 ba,
        uint256 ya,
        uint256 alpha,
        uint256 xu,
        uint256 xl
    ) external pure returns (uint256) {
        return computeReserveFixedParams(x, ba, ya, alpha, xu, xl);
    }

    function testComputeReserve(
        uint256 x,
        uint256 ba,
        uint256 ya,
        Params memory params
    ) external pure returns (uint256) {
        return computeReserve(x, ba, ya, params);
    }

    function testComputeSlope(
        uint256 ba,
        uint256 ya,
        uint256 thetaFloor,
        uint256 alphaMin
    ) external pure returns (uint256) {
        return computeAlpha(ba, ya, thetaFloor, alphaMin);
    }

    function testComputeUpperRedemptionThreshold(
        uint256 ba,
        uint256 ya,
        uint256 alpha,
        uint256 stableRedeemThresholdUpperBound,
        uint256 targetUtilizationCeiling
    ) external pure returns (uint256) {
        return computeXu(ba, ya, alpha, stableRedeemThresholdUpperBound, targetUtilizationCeiling);
    }

    function computeDerivedParams() external view returns (DerivedParams memory) {
        return createDerivedParams(_systemParams);
    }

    function setState(State calldata newState) external {
        redemptionLevel = newState.redemptionLevel;
        _gyroSupply = newState.totalGyroSupply;
    }

    function setParams(Params calldata newParams) external {
        _systemParams = newParams;
    }

    function setDecaySlopeLowerBound(uint64 alpha) external {
        _systemParams.alphaBar = alpha;
    }

    function computeRedeemAmount(State calldata state, uint256 amount) external view returns (uint256) {
        DerivedParams memory derived = createDerivedParams(systemParams);
        return computeRedeemAmount(state, systemParams, derived, amount);
    }

    function redeemTwice(
        uint256 x1,
        uint256 x2,
        uint256 y
    ) external returns (uint256 initialRedeem, uint256 secondaryRedeem) {
        initialRedeem = redeem(x1, y);
        secondaryRedeem = redeem(x2, y - initialRedeem);
    }

    function _getGyroSupply() internal view override returns (uint256) {
        return _gyroSupply;
    }
}
