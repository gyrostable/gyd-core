// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../interfaces/IReserve.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * Reserve contains the logic for the Gyroscope Reserve
 */
abstract contract Reserve is IReserve, Ownable {

}
