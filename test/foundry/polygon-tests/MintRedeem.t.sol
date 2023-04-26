// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./PolygonAddresses.sol";
import "../../../contracts/ReserveManager.sol";
import "../../../libraries/DataTypes.sol";

contract MintRedeemTest is PolygonAddresses, Test {
    address constant usdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address constant myAddress = 0x4f62aC9936D383289C13524157d95f3aB3EeF629;

    uint256 usdcDepegBlock = 40220000;

    function testReserveState() public {
        console.log(block.number);
        ReserveManager reserveManager = ReserveManager(reserveManagerAddress);

        DataTypes.ReserveState memory reserveState = reserveManager.getReserveState();
        console.log(reserveState.totalUSDValue);

        reserveState = reserveManager.getReserveState();
        console.log(reserveState.totalUSDValue);
    }
}
