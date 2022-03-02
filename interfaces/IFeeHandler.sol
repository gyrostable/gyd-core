// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../libraries/DataTypes.sol";

interface IFeeHandler {
    /// @return an order with the fees applied
    function applyFees(DataTypes.Order memory order) external view returns (DataTypes.Order memory);
}
