// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.

pragma solidity ^0.8.4;

import "../PrimaryAMMV1.sol";

contract TestingPAMMV1 is PrimaryAMMV1 {
    using FixedPoint for uint256;

    uint256 internal _gyroSupply;

    constructor(
        address _governor,
        address gyroConfig,
        Params memory params
    ) PrimaryAMMV1(_governor, gyroConfig, params) {}

    /** @dev returns Region plus additional values for situations that would be caught *before*
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

    // NOTE: needs to not be pure to be able to get transaction information from the frontend
    function computeReserveValueWithGas(
        State calldata normalizedState
    ) external view returns (uint256) {
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
