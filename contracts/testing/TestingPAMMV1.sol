pragma solidity ^0.8.4;

// SPDX-License-Identifier: MIT

import "../PrimaryAMMV1.sol";

contract TestingPAMMV1 is PrimaryAMMV1 {
    using FixedPoint for uint256;

    constructor(Params memory params) PrimaryAMMV1(params) {}

    function computeRegion(State calldata scaledState) external view returns (Region) {
        DerivedParams memory derived = createDerivedParams(systemParams);

        uint256 b = computeReserve(
            scaledState.redemptionLevel,
            scaledState.reserveValue,
            scaledState.totalGyroSupply,
            systemParams
        );
        uint256 y = scaledState.totalGyroSupply - scaledState.redemptionLevel;
        State memory state = State({
            redemptionLevel: scaledState.redemptionLevel,
            reserveValue: b,
            totalGyroSupply: y
        });

        return computeNextReserveValueRegion(state, systemParams, derived);
    }

    function computeReserveValue(State calldata scaledState) public view returns (uint256) {
        Params memory params = systemParams;
        DerivedParams memory derived = createDerivedParams(systemParams);
        uint256 b = computeReserve(
            scaledState.redemptionLevel,
            scaledState.reserveValue,
            scaledState.totalGyroSupply,
            systemParams
        );
        uint256 y = scaledState.totalGyroSupply - scaledState.redemptionLevel;
        State memory state = State({
            redemptionLevel: scaledState.redemptionLevel,
            reserveValue: b,
            totalGyroSupply: y
        });
        return computeNextReserveValue(state, params, derived);
    }

    function computeReserveValueWithGas(State calldata scaledState) external returns (uint256) {
        return computeReserveValue(scaledState);
    }

    function testComputeFixedReserve(
        uint256 x,
        uint256 ba,
        uint256 ya,
        uint256 alpha,
        uint256 xu,
        uint256 xl
    ) external pure returns (uint256) {
        return computeFixedReserve(x, ba, ya, alpha, xu, xl);
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
        return computeSlope(ba, ya, thetaFloor, alphaMin);
    }

    function testComputeUpperRedemptionThreshold(
        uint256 ba,
        uint256 ya,
        uint256 alpha,
        uint256 stableRedeemThresholdUpperBound,
        uint256 targetUtilizationCeiling
    ) external pure returns (uint256) {
        return
            computeUpperRedemptionThreshold(
                ba,
                ya,
                alpha,
                stableRedeemThresholdUpperBound,
                targetUtilizationCeiling
            );
    }

    function computeDerivedParams() external view returns (DerivedParams memory) {
        return createDerivedParams(systemParams);
    }

    function setState(State calldata newState) external {
        systemState = newState;
    }

    function setParams(Params calldata newParams) external {
        systemParams = newParams;
    }

    function setDecaySlopeLowerBound(uint64 alpha) external {
        systemParams.decaySlopeLowerBound = alpha;
    }
}
