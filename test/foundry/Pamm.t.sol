// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import {IPAMM} from "../../interfaces/IPAMM.sol";
import {PrimaryAMMV1} from "../../contracts/PrimaryAMMV1.sol";
import {TestingPAMMV1} from "../../contracts/testing/TestingPAMMV1.sol";
import {GyroConfig} from "../../contracts/GyroConfig.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";
import "../../libraries/DecimalScale.sol";
import "../../libraries/FixedPoint.sol";

contract PammTest is Test {
    // NOTE: The test* functions call associated check* functions. See their documentation for what these tests do.

    using FixedPoint for uint256;
    using DecimalScale for uint256;

    // irrelevant
    uint64 public constant OUTFLOW_MEMORY = 999993123563518195;

    uint256 public constant DELTA_SMALL = 10; // 1e-17
    uint256 public constant DELTA_MED = 1e10; // 1e-8

    // For checking xl against when it should theoretically be 1 or some other known number.
    uint256 public constant DELTA_XL_1 = 0.00000001e18;  // 1e-8

    address public constant governorAddress = address(0);
    GyroConfig internal gyroConfig;
    TestingPAMMV1 internal tpamm;

    function setUp() public virtual {
        gyroConfig = new GyroConfig();
        gyroConfig.initialize(address(this));
        // NB pamm uses gyroconfig -> gydtoken.totalSupply(). If we wanna test
        // this, we need to set up a mock token.

        IPAMM.Params memory dummyParams = IPAMM.Params(0, 0, 0, OUTFLOW_MEMORY);
        tpamm = new TestingPAMMV1(governorAddress, address(gyroConfig), dummyParams);
        // ^ Use tpamm.setParams() to set actual parameters!
    }

    /// @dev map x from [0, type max] to [a, b]
    function mapToInterval(
        uint32 x,
        uint256 a,
        uint256 b
    ) public pure returns (uint256) {
        // order matters b/c integers!
        return a + ((b - a) * uint256(x)) / type(uint32).max;
    }

    function setParams(
        uint256 alphaBar,
        uint256 xuBar,
        uint256 thetaBar
    ) public {
        setParams(IPAMM.Params(uint64(alphaBar), uint64(xuBar), uint64(thetaBar), OUTFLOW_MEMORY));
    }

    function setParams(IPAMM.Params memory params) public {
        console.log("alphaBar = %e", params.alphaBar);
        console.log("xuBar = %e", params.xuBar);
        console.log("thetaBar = %e", params.thetaBar);
        tpamm.setParams(params);
    }

    function mkParams(
        uint256 alphaBar,
        uint256 xuBar,
        uint256 thetaBar
    ) public pure returns (IPAMM.Params memory) {
        return IPAMM.Params(uint64(alphaBar), uint64(xuBar), uint64(thetaBar), OUTFLOW_MEMORY);
    }

    function mkParamsFromFuzzing(
        uint32 alphaBar0,
        uint32 xuBar0,
        uint32 thetaBar0
    ) public pure returns (IPAMM.Params memory) {
        uint256 alphaBar = mapToInterval(alphaBar0, 0.0001e18, type(uint64).max);
        uint256 xuBar = mapToInterval(xuBar0, 0.0001e18, 1e18 - 0.0001e18);
        uint256 thetaBar = mapToInterval(thetaBar0, 0.0001e18, 1e18 - 0.0001e18);
        return mkParams(alphaBar, xuBar, thetaBar);
    }

    function testExamples_DerivedValues() public {
        checkDerivedValues(mkParams(1e18, 0.3e18, 0.6e18));
        checkDerivedValues(mkParams(1e18, 0.3e18, 0.6e18));
        checkDerivedValues(mkParams(1e18, 0.3e18, 0.6e18));
        checkDerivedValues(mkParams(1e18, 0.3e18, 0.6e18));
        checkDerivedValues(mkParams(1e18, 0.3e18, 0.6e18));
        checkDerivedValues(mkParams(1e18, 0.3e18, 0.6e18));
        checkDerivedValues(mkParams(0.5e18, 0.3e18, 0.6e18));
        checkDerivedValues(mkParams(0.3e18, 0.3e18, 0.6e18));
        checkDerivedValues(mkParams(0.3e18, 0.3e18, 0.6e18));
        checkDerivedValues(mkParams(0.3e18, 0.3e18, 0.6e18));
        checkDerivedValues(mkParams(0.3e18, 0.3e18, 0.6e18));
        checkDerivedValues(mkParams(2.0e18, 0.3e18, 0.6e18));
        checkDerivedValues(mkParams(0.3e18, 0.5e18, 0.3e18)); // II l does not exist and we're in II ii
    }

    function testFuzz_DerivedValues(
        uint32 alphaBar0,
        uint32 xuBar0,
        uint32 thetaBar0
    ) public {
        // Transmogrify values into the range we need.
        // NB anything larger than uint64.max ~ 18.4 (unscaled) is pointless b/c values are cast down to uint64 when stored in params.
        uint256 alphaBar = mapToInterval(alphaBar0, 0.0001e18, type(uint64).max);
        uint256 xuBar = mapToInterval(xuBar0, 0.0001e18, 1e18 - 0.0001e18);
        uint256 thetaBar = mapToInterval(thetaBar0, 0.0001e18, 1e18 - 0.0001e18);

        checkDerivedValues(mkParams(alphaBar, xuBar, thetaBar));
    }

    /// @dev Some simple invariants for the derived params. There is only so much to check here though.
    function checkDerivedValues(IPAMM.Params memory params) public {
        setParams(params);
        PrimaryAMMV1.DerivedParams memory derived = tpamm.computeDerivedParams();

        // TODO: Once we have convinced ourselves that these tests always pass (up to rounding errors), the following variables can be eliminated:
        // - derived.xlThresholdIIHL -> Replace by 1.0
        // - derived.xlThresholdIIIHL -> Replace by 1.0
        // - derived.alphaThresholdIIIHL -> Replace by theta = 1.0 - thetaBar.
        if (
            derived.baThresholdRegionI > derived.baThresholdIIHL &&
            derived.baThresholdIIHL > derived.baThresholdRegionII
        ) {
            // Make sure we can always use 1 here.
            uint256 xl1 = tpamm.testComputeLowerRedemptionThreshold(
                derived.baThresholdIIHL,
                FixedPoint.ONE,
                params.alphaBar,
                derived.xuThresholdIIHL,
                false
            );
            uint256 xl2 = tpamm.testComputeLowerRedemptionThreshold(
                derived.baThresholdIIHL,
                FixedPoint.ONE,
                false
            );
            console.log("at baIIHL, xl1 = 1");
            assertApproxEqAbs(xl1, 1e18, DELTA_XL_1);
            console.log("at baIIHL, xl2 = 1");
            assertApproxEqAbs(xl2, 1e18, DELTA_XL_1);
        } else {
            console.log("if IIHL is out of range, default xl = 0");
            assertEq(derived.xlThresholdIIHL, 0);
        }

        if (derived.baThresholdRegionII > derived.baThresholdIIIHL) {
            uint256 theta = FixedPoint.ONE - params.thetaBar;
            uint256 alpha1 = tpamm.testComputeSlope(
                derived.baThresholdIIIHL,
                FixedPoint.ONE,
                params.thetaBar,
                params.alphaBar
            );
            console.log("at baIIIHL, alpha = theta");
            assertApproxEqAbs(alpha1, theta, DELTA_XL_1);

            // Make sure we can always use 1 and theta here, respectively.
            uint256 xl1 = tpamm.testComputeLowerRedemptionThreshold(
                derived.baThresholdIIIHL,
                FixedPoint.ONE,
                alpha1,
                0,
                false
            );
            uint256 xl2 = tpamm.testComputeLowerRedemptionThreshold(
                derived.baThresholdIIIHL,
                FixedPoint.ONE,
                false
            );
            console.log("at baIIIHL, xl1 = 1");
            assertApproxEqAbs(xl1, 1e18, DELTA_XL_1);
            console.log("at baIIIHL, xl2 = 1");
            assertApproxEqAbs(xl2, 1e18, DELTA_XL_1);
        } else {
            console.log("if IIIHL is out of range, default xl = 0");
            assertEq(derived.xlThresholdIIIHL, 0);
            console.log("if IIIHL is out of range, default alpha = 0");
            assertEq(derived.alphaThresholdIIIHL, 0);
        }
    }

    function testExamples_RegionReconstruction() public {
        // From previous (brownie) tests
        checkRegionReconstruction(0.1e18, 0.8e18, 1e18, mkParams(1e18, 0.3e18, 0.6e18));
        checkRegionReconstruction(0.1e18, 0.61e18, 1e18, mkParams(1e18, 0.3e18, 0.6e18));
        checkRegionReconstruction(0.3e18, 0.7e18, 1e18, mkParams(1e18, 0.3e18, 0.6e18));
        checkRegionReconstruction(0.8e18, 0.9e18, 1e18, mkParams(1e18, 0.3e18, 0.6e18));
        checkRegionReconstruction(0.1e18, 0.75e18, 1e18, mkParams(1e18, 0.3e18, 0.6e18));
        checkRegionReconstruction(0.2e18, 0.75e18, 1e18, mkParams(1e18, 0.3e18, 0.6e18));
        checkRegionReconstruction(0.4e18, 0.85e18, 1e18, mkParams(0.5e18, 0.3e18, 0.6e18));
        checkRegionReconstruction(0.7e18, 0.85e18, 1e18, mkParams(0.3e18, 0.3e18, 0.6e18));
        checkRegionReconstruction(0.7e18, 0.8499e18, 1e18, mkParams(0.3e18, 0.3e18, 0.6e18));
        checkRegionReconstruction(0.7e18, 0.8501e18, 1e18, mkParams(0.3e18, 0.3e18, 0.6e18));
        checkRegionReconstruction(0.2e18, 0.65e18, 1e18, mkParams(0.3e18, 0.3e18, 0.6e18));
        checkRegionReconstruction(
            0.4994994994994995e18,
            0.9e18,
            1e18,
            mkParams(2.0e18, 0.3e18, 0.6e18)
        );

        // Regression for the reconstruction bug where regions don't exist. Leads to an underflow there.
        checkRegionReconstruction(0.3e18, 0.9e18, 1e18, mkParams(0.3e18, 0.5e18, 0.3e18)); // II l does not exist and we're in II ii
    }

    function testFuzzRegression_RegionDetection() public {
        testFuzz_RegionDetection(1, 4254, 12, 4180781539, 0, 0);
    }

    function testFuzz_RegionDetection(
        uint32 x0,
        uint32 ba0,
        uint32 ya0,
        uint32 alphaBar0,
        uint32 xuBar0,
        uint32 thetaBar0
    ) public {
        IPAMM.Params memory params = mkParamsFromFuzzing(alphaBar0, xuBar0, thetaBar0);

        uint256 ramin = params.thetaBar - params.thetaBar / 100;

        // Testing anchor GYD amounts and reserve values up to 100B such that reserve ratios are within (theta_bar - small) and (1 + small)
        uint256 ya = mapToInterval(ya0, 0.0001e18, 1e11 * 1e18);
        uint256 ba = mapToInterval(ba0, (ramin * ya) / 1e18, (1.01e18 * ya) / 1e18);
        uint256 x = mapToInterval(x0, 0, ya);
        vm.assume(ya > ba && ba > ya.mulDown(params.thetaBar));

        checkRegionReconstruction(x, ba, ya, params);
    }

    /// @dev Given x and an anchor point, first compute the region directly; then compare against
    /// the reconstructed region at the implied state.
    function checkRegionReconstruction(
        uint256 x,
        uint256 ba,
        uint256 ya,
        IPAMM.Params memory params
    ) public {
        setParams(params);
        console.log("x = %e", x);
        console.log("ba = %e", ba);
        console.log("ya = %e", ya);

        PrimaryAMMV1.State memory anchoredState = PrimaryAMMV1.State(x, ba, ya);

        uint256 regTrue = tpamm.computeTrueRegion(anchoredState);
        uint256 regReconstructed = tpamm.reconstructRegionFromAnchor(anchoredState);
        assertEq(regTrue, regReconstructed);
    }

    function testExamples_BReconstructionFromB() public {
        // NB these are basically some random states.
        checkBReconstructionFromB(0.1e18, 0.5e18, 1e18, mkParams(1e18, 0.3e18, 0.6e18));
        checkBReconstructionFromB(0.1e18, 0.31e18, 1e18, mkParams(1e18, 0.3e18, 0.6e18));
        checkBReconstructionFromB(0.3e18, 0.7e18, 1e18, mkParams(1e18, 0.3e18, 0.6e18));
        checkBReconstructionFromB(0.8e18, 0.9e18, 1e18, mkParams(1e18, 0.3e18, 0.6e18));
        checkBReconstructionFromB(0.1e18, 0.81e18, 1e18, mkParams(1e18, 0.3e18, 0.6e18));
        checkBReconstructionFromB(0.2e18, 0.04e18, 1e18, mkParams(1e18, 0.3e18, 0.6e18));
        checkBReconstructionFromB(0.4e18, 0.85e18, 1e18, mkParams(0.5e18, 0.3e18, 0.6e18));
        checkBReconstructionFromB(0.7e18, 0.85e18, 1e18, mkParams(0.3e18, 0.3e18, 0.6e18));
        checkBReconstructionFromB(0.7e18, 0.8499e18, 1e18, mkParams(0.3e18, 0.3e18, 0.6e18));
        checkBReconstructionFromB(0.7e18, 0.8501e18, 1e18, mkParams(0.3e18, 0.3e18, 0.6e18));
        checkBReconstructionFromB(0.2e18, 0.65e18, 1e18, mkParams(0.3e18, 0.3e18, 0.6e18));
        checkBReconstructionFromB(
            0.4994994994994995e18,
            0.9e18,
            1e18,
            mkParams(2.0e18, 0.3e18, 0.6e18)
        );
    }

    function testFuzz_BReconstructionFromB(
        uint32 x0,
        uint32 b0,
        uint32 y0,
        uint32 alphaBar0,
        uint32 xuBar0,
        uint32 thetaBar0
    ) public {
        IPAMM.Params memory params = mkParamsFromFuzzing(alphaBar0, xuBar0, thetaBar0);

        uint256 rmin = params.thetaBar - params.thetaBar / 100;

        // Testing GYD amounts and reserve values up to 100B such that reserve ratios are within (theta_bar - small) and (1 + small)
        uint256 y = mapToInterval(y0, 0.0001e18, 1e11 * 1e18);
        uint256 b = mapToInterval(b0, (rmin * y) / 1e18, (1.01e18 * y) / 1e18);
        uint256 x = mapToInterval(x0, 0, y);
        // TODO test x slightly > y due to rounding errors & make sure it's not crashing. Somewhere (not here).

        checkBReconstructionFromB(x, b, y, params);
    }

    /// @dev Given a state, reconstruct the anchor point and from there its own b (= reserve value).
    /// This should yield the state's reserve value back.
    function checkBReconstructionFromB(
        uint256 x,
        uint256 b,
        uint256 y,
        IPAMM.Params memory params
    ) public {
        tpamm.setParams(params);
        console.log("y = %e", y);
        console.log("b = %e", b);
        console.log("x = %e", x);

        PrimaryAMMV1.State memory state = PrimaryAMMV1.State(x, b, y);

        uint256 reconstructedB = tpamm.roundTripState(state);
        assertApproxEqAbs(b, reconstructedB, DELTA_SMALL);
    }

    function testExamples_RedeemFromBa() public {
        checkRedeemFromBa(0.1e18, 0.1e18, 0.8e18, 1e18, mkParams(1e18, 0.3e18, 0.6e18));
        checkRedeemFromBa(0.2e18, 0.1e18, 0.61e18, 1e18, mkParams(1e18, 0.3e18, 0.6e18));
        checkRedeemFromBa(0.3e18, 0.3e18, 0.7e18, 1e18, mkParams(1e18, 0.3e18, 0.6e18));
        checkRedeemFromBa(0.1e18, 0.8e18, 0.9e18, 1e18, mkParams(1e18, 0.3e18, 0.6e18));
        checkRedeemFromBa(0.899e18, 0.1e18, 0.75e18, 1e18, mkParams(1e18, 0.3e18, 0.6e18));
        checkRedeemFromBa(0.2e18, 0.2e18, 0.75e18, 1e18, mkParams(1e18, 0.3e18, 0.6e18));
        checkRedeemFromBa(0.1e18, 0.4e18, 0.85e18, 1e18, mkParams(0.5e18, 0.3e18, 0.6e18));
        checkRedeemFromBa(0.1e18, 0.7e18, 0.85e18, 1e18, mkParams(0.3e18, 0.3e18, 0.6e18));
        checkRedeemFromBa(0.2e18, 0.7e18, 0.8499e18, 1e18, mkParams(0.3e18, 0.3e18, 0.6e18));
        checkRedeemFromBa(0.1e18, 0.7e18, 0.8501e18, 1e18, mkParams(0.3e18, 0.3e18, 0.6e18));
        checkRedeemFromBa(0.7e18, 0.2e18, 0.65e18, 1e18, mkParams(0.3e18, 0.3e18, 0.6e18));
        checkRedeemFromBa(
            0.4994994994994995e18,
            0.4994994994994995e18,
            0.9e18,
            1e18,
            mkParams(2.0e18, 0.3e18, 0.6e18)
        );
        checkRedeemFromBa(0.5e18, 0.3e18, 0.9e18, 1e18, mkParams(0.3e18, 0.5e18, 0.3e18)); // II l does not exist and we're in II ii
    }

    function testFuzz_RedeemFromBa(
        uint32 dx0,
        uint32 x0,
        uint32 ba0,
        uint32 ya0,
        uint32 alphaBar0,
        uint32 xuBar0,
        uint32 thetaBar0
    ) public {
        IPAMM.Params memory params = mkParamsFromFuzzing(alphaBar0, xuBar0, thetaBar0);

        uint256 ramin = params.thetaBar - params.thetaBar / 100;

        // Testing anchor GYD amounts and reserve values up to 100B such that reserve ratios are within (theta_bar - small) and (1 + small)
        uint256 ya = mapToInterval(ya0, 0.0001e18, 1e11 * 1e18);
        uint256 ba = mapToInterval(ba0, (ramin * ya) / 1e18, (1.01e18 * ya) / 1e18);
        uint256 x = mapToInterval(x0, 0, ya);
        vm.assume(x < ya); // we could've excluded the endpoint above somehow but that's painful.
        vm.assume(ya > ba && ba > ya.mulDown(params.thetaBar));
        uint256 dx = mapToInterval(dx0, 0, ya - x);

        checkRedeemFromBa(dx, x, ba, ya, params);
    }

    /// @dev Given an anchor point, x, and a redeption amount dx, compute directly the reserve value
    /// before and after the redemption. The difference should be the redemption amount computed
    /// via the usual PAMM logic (= reconstruction, then computation of the new b).
    function checkRedeemFromBa(
        uint256 dx,
        uint256 x,
        uint256 ba,
        uint256 ya,
        IPAMM.Params memory params
    ) public {
        setParams(params);
        console.log("dx = %e", dx);
        console.log("x = %e", x);
        console.log("ba = %e", ba);
        console.log("ya = %e", ya);

        uint256 b;
        {
            PrimaryAMMV1.State memory anchoredState = PrimaryAMMV1.State(x, ba, ya);
            b = tpamm.computeReserveValueFromAnchor(anchoredState);
        }
        uint256 y = ya - x;

        PrimaryAMMV1.State memory anchoredState1 = PrimaryAMMV1.State(x + dx, ba, ya);
        uint256 b1 = tpamm.computeReserveValueFromAnchor(anchoredState1);

        PrimaryAMMV1.State memory state = PrimaryAMMV1.State(x, b, y);
        uint256 db = tpamm.computeRedeemAmount(state, dx);

        assertApproxEqAbs(db, b - b1, DELTA_MED);
    }

    // Could also do a redemption test.
}
