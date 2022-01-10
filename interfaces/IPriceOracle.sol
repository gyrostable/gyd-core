// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../libraries/DataTypes.sol";

interface IPriceOracle {
    /// @notice Quotes the USD value of `monetaryAmount`
    /// @param monetaryAmount a tokens and associated amount to be priced
    /// @return the USD value of the token
    function getUSDValue(DataTypes.MonetaryAmount memory monetaryAmount)
        external
        view
        returns (uint256);

    /// @notice Quotes the USD value of `monetaryAmounts`
    /// @param monetaryAmounts a basket of tokens and associated amounts to be priced
    /// @return the USD value of the tokens
    function getUSDValue(DataTypes.MonetaryAmount[] memory monetaryAmounts)
        external
        view
        returns (uint256);
}
