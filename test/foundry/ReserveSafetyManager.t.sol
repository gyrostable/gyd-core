// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {TestingReserveSafetyManager} from "../../contracts/testing/TestingReserveSafetyManager.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";

contract ReserveSafetyManagerTest is Test {
    TestingReserveSafetyManager internal reserveSafetyManager;

    address public constant governorAddress = address(0);
    uint256 internal _maxAllowedVaultDeviation = 300000000000000000;
    uint256 internal _stablecoinMaxDeviation = 50000000000000000;
    uint256 internal _minTokenPrice = 10000000000000;

    function setUp() public virtual {
        reserveSafetyManager = new TestingReserveSafetyManager(
            governorAddress,
            _maxAllowedVaultDeviation,
            _stablecoinMaxDeviation,
            _minTokenPrice
        );
    }

    function testVaultWithOffPegWeightFalls() public {
        // DataTypes.Metadata _metadata = DataTypes.Metadata(DataTypes.Vaul)
    }
}
