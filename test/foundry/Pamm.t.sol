// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import {IPAMM} from "../../interfaces/IPAMM.sol";
import {PrimaryAMMV1} from "../../contracts/PrimaryAMMV1.sol";
import {TestingPAMMV1} from "../../contracts/testing/TestingPAMMV1.sol";
import {GyroConfig} from "../../contracts/GyroConfig.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";
import "../../libraries/ConfigKeys.sol";
import "../../libraries/DecimalScale.sol";
import "../../libraries/FixedPoint.sol";
import {FreezableTransparentUpgradeableProxy, ProxyAdmin} from "../../contracts/FreezableProxy.sol";

contract PammTest is Test {
    // NOTE: The test* functions call associated check* functions. See their documentation for what these tests do.

    using FixedPoint for uint256;
    using DecimalScale for uint256;

    // irrelevant
    uint64 public constant OUTFLOW_MEMORY = 999993123563518195;

    uint256 public constant DELTA_SMALL = 10; // 1e-17
    uint256 public constant DELTA_MED = 1e10; // 1e-8

    // For checking xl against when it should theoretically be 1 or some other known number.
    uint256 public constant DELTA_XL_1 = 0.00000001e18; // 1e-8

    address public constant governorAddress = address(0);
    GyroConfig internal gyroConfig;
    TestingPAMMV1 internal tpamm;

    function setUp() public virtual {
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        gyroConfig = new GyroConfig();
        FreezableTransparentUpgradeableProxy proxy = new FreezableTransparentUpgradeableProxy(
            address(gyroConfig),
            address(proxyAdmin),
            abi.encodeWithSelector(gyroConfig.initialize.selector, address(this))
        );
        gyroConfig = GyroConfig(address(proxy));
        // gyroConfig.initialize(address(this));
        // NB pamm uses gyroconfig -> gydtoken.totalSupply(). If we wanna test
        // this, we need to set up a mock token.

        // We don't test REDEEM_DISCOUNT_RATIO here, setting it to 0 is disable.
        gyroConfig.setUint(ConfigKeys.REDEEM_DISCOUNT_RATIO, 0);

        IPAMM.Params memory dummyParams = IPAMM.Params(0, 0, 0, OUTFLOW_MEMORY);
        tpamm = new TestingPAMMV1(governorAddress, address(gyroConfig), dummyParams);
        // ^ Use tpamm.setParams() to set actual parameters!
    }

    // "abs or rel" equality logic typically used for floating-point numbers. Obv we *don't* use
    // floating point so bounds need to be driven by fundamental rather than technical reasons.
    function assertApproxEqRelAbs(
        uint256 actual,
        uint256 expd,
        uint256 delta_rel,
        uint256 delta_abs
    ) public {
        uint256 delta_abs_actual = actual.absSub(expd);
        uint256 delta_rel_actual = delta_abs_actual.divDown(expd);
        if (delta_abs_actual > delta_abs && delta_rel_actual > delta_rel) {
            console.log("Error: a ~= b not satisfied [uint]");
            console.log("    Expected: %e", expd);
            console.log("      Actual: %e", actual);
            console.log(" Max %% Delta: %e", delta_rel);
            console.log("     %% Delta: %e", delta_rel_actual);
            console.log("   Max Delta: %e", delta_abs);
            console.log("       Delta: %e", delta_abs_actual);
            assertFalse(true);
        }
    }

    function assertApproxLeRelAbs(
        uint256 actual,
        uint256 expd,
        uint256 delta_rel,
        uint256 delta_abs
    ) public {
        if (actual <= expd) return;
        assertApproxEqRelAbs(actual, expd, delta_rel, delta_abs);
    }

    /// @dev map x from [0, type max] to [a, b]
    function mapToInterval(
        uint32 x,
        uint256 a,
        uint256 b
    ) public pure returns (uint256) {
        vm.assume(a < b); // retry for fuzz tests, fail for regular tests (not used there)

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

    function logAnchoredState(PrimaryAMMV1.State memory state) public {
        console.log("x = %e", state.redemptionLevel);
        console.log("ba = %e", state.reserveValue);
        console.log("ya = %e", state.totalGyroSupply);
    }

    function logState(PrimaryAMMV1.State memory state) public {
        console.log("x = %e", state.redemptionLevel);
        console.log("b = %e", state.reserveValue);
        console.log("y = %e", state.totalGyroSupply);
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

    function mkState(
        uint256 x,
        uint256 b,
        uint256 y
    ) public pure returns (PrimaryAMMV1.State memory) {
        return PrimaryAMMV1.State(x, b, y);
    }

    function mkParamsFromFuzzing(
        uint32 alphaBar0,
        uint32 xuBar0,
        uint32 thetaBar0
    ) public pure returns (IPAMM.Params memory) {
        // NB max possible values are type(uint64).max b/c these values will be cast down to uint64.
        // But we choose hand-crafted, more realistic values.

        // SOMEDAY These parameters are quite wide. Could be tighter:
        // - min alphaBar value could also be 100bp. (currently 10bp)
        // - max xuBar bound can probably be even lower. xuBar ~ normal outflow levels probably.
        // - min thetaBar can also be increased further if helps. Any thetaBar < 20% is strange.
        uint256 alphaBar = mapToInterval(alphaBar0, 0.001e18, type(uint64).max);
        uint256 xuBar = mapToInterval(xuBar0, 0.0001e18, 0.5e18);
        uint256 thetaBar = mapToInterval(thetaBar0, 0.1e18, 1e18 - 0.001e18);
        return mkParams(alphaBar, xuBar, thetaBar);
    }

    function mkAnchoredStateFromFuzzing(
        uint32 x0,
        uint32 ba0,
        uint32 ya0,
        IPAMM.Params memory params
    ) public pure returns (PrimaryAMMV1.State memory anchoredState) {
        // ya: We use values between (trivial) and 500M GYD.
        // SOMEDAY For larger values, some rounding errors are amplified to small but non-trivial values in some extreme situations.
        // This would have to be looked at in more detail separately. See Steffen's notes from 2023-06-15.
        uint256 ya = mapToInterval(ya0, 10e18, 500e6 * 1e18);
        // NB The lower-bound gap is so that alpha does not become extremely large, leading to instability.
        uint256 ba = mapToInterval(ba0, ((params.thetaBar + 0.0000001e18) * ya) / 1e18, ya);
        uint256 x = mapToInterval(x0, 0, ya);
        // This is only to ensure inequalities above are strict.
        vm.assume(ya > ba && ba > ya.mulDown(params.thetaBar));
        return mkState(x, ba, ya);
    }

    function mkStateFromFuzzing(
        uint32 x0,
        uint32 b0,
        uint32 y0,
        IPAMM.Params memory params
    ) public pure returns (PrimaryAMMV1.State memory state) {
        // Nothing special here yet.
        return mkAnchoredStateFromFuzzing(x0, b0, y0, params);
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
        IPAMM.Params memory params = mkParamsFromFuzzing(alphaBar0, xuBar0, thetaBar0);
        checkDerivedValues(params);
    }

    /// @dev Some simple invariants for the derived params. There is only so much to check here though.
    function checkDerivedValues(IPAMM.Params memory params) public {
        console.log("--------------------------------------------------------------------------");
        setParams(params);
        PrimaryAMMV1.DerivedParams memory derived = tpamm.computeDerivedParams();

        // The following checks theory and justifies the following replacements we made for values that don't actually need to be computed.
        // - derived.xlThresholdIIHL -> 1.0
        // - derived.xlThresholdIIIHL -> 1.0
        // - derived.alphaThresholdIIIHL -> theta = 1.0 - thetaBar.
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
        }
        // else, this value is not used.

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
        }
        // else, these values are not used.
    }

    function testExamples_RegionReconstruction() public {
        // From previous (brownie) tests
        checkRegionReconstruction(mkState(0.1e18, 0.8e18, 1e18), mkParams(1e18, 0.3e18, 0.6e18));
        checkRegionReconstruction(mkState(0.1e18, 0.61e18, 1e18), mkParams(1e18, 0.3e18, 0.6e18));
        checkRegionReconstruction(mkState(0.3e18, 0.7e18, 1e18), mkParams(1e18, 0.3e18, 0.6e18));
        checkRegionReconstruction(mkState(0.8e18, 0.9e18, 1e18), mkParams(1e18, 0.3e18, 0.6e18));
        checkRegionReconstruction(mkState(0.1e18, 0.75e18, 1e18), mkParams(1e18, 0.3e18, 0.6e18));
        checkRegionReconstruction(mkState(0.2e18, 0.75e18, 1e18), mkParams(1e18, 0.3e18, 0.6e18));
        checkRegionReconstruction(mkState(0.4e18, 0.85e18, 1e18), mkParams(0.5e18, 0.3e18, 0.6e18));
        checkRegionReconstruction(mkState(0.7e18, 0.85e18, 1e18), mkParams(0.3e18, 0.3e18, 0.6e18));
        checkRegionReconstruction(
            mkState(0.7e18, 0.8499e18, 1e18),
            mkParams(0.3e18, 0.3e18, 0.6e18)
        );
        checkRegionReconstruction(
            mkState(0.7e18, 0.8501e18, 1e18),
            mkParams(0.3e18, 0.3e18, 0.6e18)
        );
        checkRegionReconstruction(mkState(0.2e18, 0.65e18, 1e18), mkParams(0.3e18, 0.3e18, 0.6e18));
        checkRegionReconstruction(
            mkState(0.4994994994994995e18, 0.9e18, 1e18),
            mkParams(2.0e18, 0.3e18, 0.6e18)
        );

        // Regression for the reconstruction bug where regions don't exist. Leads to an underflow there.
        checkRegionReconstruction(mkState(0.3e18, 0.9e18, 1e18), mkParams(0.3e18, 0.5e18, 0.3e18)); // II l does not exist and we're in II ii
    }

    // // TESTS DISABLED b/c region reconstruction is brittle for values that are right on the edge. The other tests (b reconstrution, redeem test make) ensure that this has no ill effects. (so in some cases a different region may be detected, but this will lead to the same result within a tight margin)
    // function testFuzzRegression_RegionReconstruction() public {
    //     testFuzz_RegionReconstruction(0, 1, 0, 0, 0, 0);
    // }
    //
    // function testFuzz_RegionReconstruction(
    //     uint32 x0,
    //     uint32 ba0,
    //     uint32 ya0,
    //     uint32 alphaBar0,
    //     uint32 xuBar0,
    //     uint32 thetaBar0
    // ) public {
    //     IPAMM.Params memory params = mkParamsFromFuzzing(alphaBar0, xuBar0, thetaBar0);
    //     PrimaryAMMV1.State memory state = mkAnchoredStateFromFuzzing(x0, ba0, ya0, params);
    //     checkRegionReconstruction(state, params);
    // }

    /// @dev Given x and an anchor point, first compute the region directly; then compare against
    /// the reconstructed region at the implied state.
    function checkRegionReconstruction(
        PrimaryAMMV1.State memory anchoredState,
        IPAMM.Params memory params
    ) public {
        console.log("--------------------------------------------------------------------------");
        setParams(params);
        logAnchoredState(anchoredState);

        uint256 regTrue = tpamm.computeTrueRegion(anchoredState);
        uint256 regReconstructed = tpamm.reconstructRegionFromAnchor(anchoredState);
        assertEq(regTrue, regReconstructed);
    }

    function testExamples_BReconstructionFromB() public {
        // NB these are basically some random states.
        checkBReconstructionFromB(mkState(0.1e18, 0.5e18, 1e18), mkParams(1e18, 0.3e18, 0.6e18));
        checkBReconstructionFromB(mkState(0.1e18, 0.31e18, 1e18), mkParams(1e18, 0.3e18, 0.6e18));
        checkBReconstructionFromB(mkState(0.3e18, 0.7e18, 1e18), mkParams(1e18, 0.3e18, 0.6e18));
        checkBReconstructionFromB(mkState(0.8e18, 0.9e18, 1e18), mkParams(1e18, 0.3e18, 0.6e18));
        checkBReconstructionFromB(mkState(0.1e18, 0.81e18, 1e18), mkParams(1e18, 0.3e18, 0.6e18));
        checkBReconstructionFromB(mkState(0.2e18, 0.04e18, 1e18), mkParams(1e18, 0.3e18, 0.6e18));
        checkBReconstructionFromB(mkState(0.4e18, 0.85e18, 1e18), mkParams(0.5e18, 0.3e18, 0.6e18));
        checkBReconstructionFromB(mkState(0.7e18, 0.85e18, 1e18), mkParams(0.3e18, 0.3e18, 0.6e18));
        checkBReconstructionFromB(
            mkState(0.7e18, 0.8499e18, 1e18),
            mkParams(0.3e18, 0.3e18, 0.6e18)
        );
        checkBReconstructionFromB(
            mkState(0.7e18, 0.8501e18, 1e18),
            mkParams(0.3e18, 0.3e18, 0.6e18)
        );
        checkBReconstructionFromB(mkState(0.2e18, 0.65e18, 1e18), mkParams(0.3e18, 0.3e18, 0.6e18));
        checkBReconstructionFromB(
            mkState(0.4994994994994995e18, 0.9e18, 1e18),
            mkParams(2.0e18, 0.3e18, 0.6e18)
        );

        // Regression for checkRedeemFromBa().
        checkBReconstructionFromB(
            mkState(0.3e18, 0.602035718005177562e18, 0.7e18),
            mkParams(3e17, 5e17, 3e17)
        );
    }

    function testFuzzRegression_BReconstructionFromB() public {
        testFuzz_BReconstructionFromB(1559196544, 1885762392, 1044300757, 1910203372, 3604, 6434);
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
        PrimaryAMMV1.State memory state = mkStateFromFuzzing(x0, b0, y0, params);
        checkBReconstructionFromB(state, params);
    }

    /// @dev Given a state, reconstruct the anchor point and from there its own b (= reserve value).
    /// This should yield the state's reserve value back.
    function checkBReconstructionFromB(PrimaryAMMV1.State memory state, IPAMM.Params memory params)
        public
    {
        console.log("--------------------------------------------------------------------------");
        setParams(params);
        logState(state);
        uint256 reconstructedB = tpamm.roundTripState(state);
        // assertApproxEqRel(state.reserveValue, reconstructedB, 1e12);  // 1e-6 relative
        assertApproxEqRelAbs(state.reserveValue, reconstructedB, 1e10, 0.01e18); // 1e-8 relative or 0.01 absolute
    }

    function testExamples_RedeemFromBa() public {
        checkRedeemFromBa(0.1e18, mkState(0.1e18, 0.8e18, 1e18), mkParams(1e18, 0.3e18, 0.6e18));
        checkRedeemFromBa(0.2e18, mkState(0.1e18, 0.61e18, 1e18), mkParams(1e18, 0.3e18, 0.6e18));
        checkRedeemFromBa(0.3e18, mkState(0.3e18, 0.7e18, 1e18), mkParams(1e18, 0.3e18, 0.6e18));
        checkRedeemFromBa(0.1e18, mkState(0.8e18, 0.9e18, 1e18), mkParams(1e18, 0.3e18, 0.6e18));
        checkRedeemFromBa(0.899e18, mkState(0.1e18, 0.75e18, 1e18), mkParams(1e18, 0.3e18, 0.6e18));
        checkRedeemFromBa(0.2e18, mkState(0.2e18, 0.75e18, 1e18), mkParams(1e18, 0.3e18, 0.6e18));
        checkRedeemFromBa(0.1e18, mkState(0.4e18, 0.85e18, 1e18), mkParams(0.5e18, 0.3e18, 0.6e18));
        checkRedeemFromBa(0.1e18, mkState(0.7e18, 0.85e18, 1e18), mkParams(0.3e18, 0.3e18, 0.6e18));
        checkRedeemFromBa(
            0.2e18,
            mkState(0.7e18, 0.8499e18, 1e18),
            mkParams(0.3e18, 0.3e18, 0.6e18)
        );
        checkRedeemFromBa(
            0.1e18,
            mkState(0.7e18, 0.8501e18, 1e18),
            mkParams(0.3e18, 0.3e18, 0.6e18)
        );
        checkRedeemFromBa(0.7e18, mkState(0.2e18, 0.65e18, 1e18), mkParams(0.3e18, 0.3e18, 0.6e18));
        checkRedeemFromBa(
            0.4994994994994995e18,
            mkState(0.4994994994994995e18, 0.9e18, 1e18),
            mkParams(2.0e18, 0.3e18, 0.6e18)
        );
        checkRedeemFromBa(0.5e18, mkState(0.3e18, 0.9e18, 1e18), mkParams(0.3e18, 0.5e18, 0.3e18)); // II l does not exist and we're in II ii
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
        PrimaryAMMV1.State memory anchoredState = mkAnchoredStateFromFuzzing(x0, ba0, ya0, params);
        uint256 dx = mapToInterval(
            dx0,
            1e18,
            anchoredState.totalGyroSupply - anchoredState.redemptionLevel
        );
        checkRedeemFromBa(dx, anchoredState, params);
    }

    function testFuzzRegression_RedeemFromBa() public {
        testFuzz_RedeemFromBa(4294967295, 0, 2147268247, 219171, 0, 0, 9845018);
        testFuzz_RedeemFromBa(4294967295, 0, 2147249903, 4139298295, 0, 0, 1);
    }

    /// @dev Given an anchor point, x, and a redeption amount dx, compute directly the reserve value
    /// before and after the redemption. The difference should be the redemption amount computed
    /// via the usual PAMM logic (= reconstruction, then computation of the new b) at the state before redemption.
    function checkRedeemFromBa(
        uint256 dx,
        PrimaryAMMV1.State memory anchoredState,
        IPAMM.Params memory params
    ) public {
        console.log("--------------------------------------------------------------------------");
        setParams(params);
        console.log("dx = %e", dx);
        logAnchoredState(anchoredState);

        console.log(
            "alpha = %e",
            tpamm.testComputeSlope(anchoredState.reserveValue, anchoredState.totalGyroSupply)
        );

        console.log(
            "ba (normalized) = %e",
            anchoredState.reserveValue.divDown(anchoredState.totalGyroSupply)
        );
        console.log(
            "x (normalized)  = %e",
            anchoredState.redemptionLevel.divDown(anchoredState.totalGyroSupply)
        );
        console.log("dx (normalized)  = %e", dx.divDown(anchoredState.totalGyroSupply));
        console.log(
            "alpha (normalized) = %e",
            tpamm.testComputeSlope(
                anchoredState.reserveValue.divDown(anchoredState.totalGyroSupply),
                1e18
            )
        );

        console.log("> computeReserveValueFromAnchor");
        uint256 b = tpamm.computeReserveValueFromAnchor(anchoredState);
        console.log("b = %e", b);
        uint256 y = anchoredState.totalGyroSupply - anchoredState.redemptionLevel;

        PrimaryAMMV1.State memory anchoredState1 = PrimaryAMMV1.State({
            redemptionLevel: anchoredState.redemptionLevel + dx,
            totalGyroSupply: anchoredState.totalGyroSupply,
            reserveValue: anchoredState.reserveValue
        });

        console.log("> computeReserveValueFromAnchor");
        uint256 b1 = tpamm.computeReserveValueFromAnchor(anchoredState1);

        PrimaryAMMV1.State memory state = PrimaryAMMV1.State(anchoredState.redemptionLevel, b, y);
        console.log("> computeRedeemAmount, state =");
        logState(state);
        uint256 db = tpamm.computeRedeemAmount(state, dx);

        // NB This *can* fail in extreme settings (by a small margin) unless we explicitly avoid it in computeRedeemAmount()!
        console.log("assert redemption price <= 1");
        assertApproxLeRelAbs(db, dx, 0, 0.01e18);

        console.log("assert redemption amounts match");
        // The following bounds are economially motivated based on a mint/redeem fee and minimum tx cost.
        assertApproxEqRelAbs(db, b - b1, 1e13, 0.03e18); // rel=1e-5, abs=0.03 USD
    }
}
