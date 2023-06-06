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

    // TODO test some invariants about derived values, e.g. xl=1

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
