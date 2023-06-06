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
    using FixedPoint for uint256;
    using DecimalScale for uint256;

    // irrelevant
    uint64 public constant OUTFLOW_MEMORY = 999993123563518195;

    uint public constant DELTA_SMALL = 1;  // 1e-18
    uint public constant DELTA_MED = 1e10; // 1e-8

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

    function testDerivedValuesExamples() public {
        checkDerivedValues(1e18, 0.3e18, 0.6e18);
        checkDerivedValues(1e18, 0.3e18, 0.6e18);
        checkDerivedValues(1e18, 0.3e18, 0.6e18);
        checkDerivedValues(1e18, 0.3e18, 0.6e18);
        checkDerivedValues(1e18, 0.3e18, 0.6e18);
        checkDerivedValues(1e18, 0.3e18, 0.6e18);
        checkDerivedValues(0.5e18, 0.3e18, 0.6e18);
        checkDerivedValues(0.3e18, 0.3e18, 0.6e18);
        checkDerivedValues(0.3e18, 0.3e18, 0.6e18);
        checkDerivedValues(0.3e18, 0.3e18, 0.6e18);
        checkDerivedValues(0.3e18, 0.3e18, 0.6e18);
        checkDerivedValues(2.0e18, 0.3e18, 0.6e18);
        checkDerivedValues(0.3e18, 0.5e18, 0.3e18); // II l does not exist and we're in II ii
    }

    /// @dev map x from [0, type max] to [a, b]
    function mapToInterval(uint32 x, uint a, uint b) public pure returns (uint) {
        // order matters b/c integers!
        return a + (b - a) * uint(x) / type(uint32).max;
    }

    /// forge-config: default.fuzz.runs = 10000
    function testFuzz_derivedValues(uint32 alphaBar0, uint32 xuBar0, uint32 thetaBar0) public {
        // Transmogrify values into the range we need.
        // NB anything larger than uint64.max ~ 18.4 (unscaled) is pointless b/c values are cast down to uint64 when stored in params.
        uint alphaBar = mapToInterval(alphaBar0, 0.0001e18, type(uint64).max);
        uint xuBar = mapToInterval(xuBar0, 0.0001e18, 1e18 - 0.0001e18);
        uint thetaBar = mapToInterval(thetaBar0, 0.0001e18, 1e18 - 0.0001e18);

        console.log("alphaBar = %e", alphaBar);
        console.log("xuBar = %e", xuBar);
        console.log("thetaBar = %e", thetaBar);

        checkDerivedValues(alphaBar, xuBar, thetaBar);
    }

    function checkDerivedValues(uint alphaBar, uint xuBar, uint thetaBar) public {
        IPAMM.Params memory params = IPAMM.Params(uint64(alphaBar), uint64(xuBar), uint64(thetaBar), OUTFLOW_MEMORY);
        tpamm.setParams(params);
        PrimaryAMMV1.DerivedParams memory derived = tpamm.computeDerivedParams();

        // Some simple invariants. We can't do too much here b/c our only spec is the PAMM implementation itself.
        if (derived.baThresholdRegionI > derived.baThresholdIIHL && derived.baThresholdIIHL > derived.baThresholdRegionII) {
            // TODO when this test passes consistently, remove xlThresholdIIHL and replace by 1.
            assertApproxEqAbsDecimal(derived.xlThresholdIIHL, 1e18, DELTA_MED, 18);
            // xu is non-trivial!
        } else {
            assertEq(derived.xlThresholdIIHL, 0);
        }

        if (derived.baThresholdRegionII > derived.baThresholdIIIHL) {
            assertApproxEqAbsDecimal(derived.xlThresholdIIIHL, 1e18, DELTA_MED, 18);
            // TODO alpha should just be theta = 1 - theta_bar.
        } else {
            assertEq(derived.xlThresholdIIIHL, 0);
        }
    }

    function testRegionReconstructionExamples() public {
        // From previous (brownie) tests
        checkRegionReconstruction(0.1e18, 0.8e18, 1e18, 1e18, 0.3e18, 0.6e18);
        checkRegionReconstruction(0.1e18, 0.61e18, 1e18, 1e18, 0.3e18, 0.6e18);
        checkRegionReconstruction(0.3e18, 0.7e18, 1e18, 1e18, 0.3e18, 0.6e18);
        checkRegionReconstruction(0.8e18, 0.9e18, 1e18, 1e18, 0.3e18, 0.6e18);
        checkRegionReconstruction(0.1e18, 0.75e18, 1e18, 1e18, 0.3e18, 0.6e18);
        checkRegionReconstruction(0.2e18, 0.75e18, 1e18, 1e18, 0.3e18, 0.6e18);
        checkRegionReconstruction(0.4e18, 0.85e18, 1e18, 0.5e18, 0.3e18, 0.6e18);
        checkRegionReconstruction(0.7e18, 0.85e18, 1e18, 0.3e18, 0.3e18, 0.6e18);
        checkRegionReconstruction(0.7e18, 0.8499e18, 1e18, 0.3e18, 0.3e18, 0.6e18);
        checkRegionReconstruction(0.7e18, 0.8501e18, 1e18, 0.3e18, 0.3e18, 0.6e18);
        checkRegionReconstruction(0.2e18, 0.65e18, 1e18, 0.3e18, 0.3e18, 0.6e18);
        checkRegionReconstruction(0.4994994994994995e18, 0.9e18, 1e18, 2.0e18, 0.3e18, 0.6e18);

        // Regression for the reconstruction bug where regions don't exist. Leads to an underflow there.
        checkRegionReconstruction(0.3e18, 0.9e18, 1e18, 0.3e18, 0.5e18, 0.3e18); // II l does not exist and we're in II ii

        // TODO fuzz
    }

    function checkRegionReconstruction(uint x, uint ba, uint ya, uint alphaBar, uint xuBar, uint thetaBar) public {
        PrimaryAMMV1.State memory anchoredState = PrimaryAMMV1.State(x, ba, ya);
        IPAMM.Params memory params = IPAMM.Params(uint64(alphaBar), uint64(xuBar), uint64(thetaBar), OUTFLOW_MEMORY);
        tpamm.setParams(params);

        uint regTrue = tpamm.computeTrueRegion(anchoredState);
        uint regReconstructed = tpamm.computeRegion(anchoredState);
        assertEq(regTrue, regReconstructed);
    }

    // TODO b reconstruction test (given ba compute b and reconstruct to compute b again, make sure they match)
    // (we could also just give b as an input)
}
