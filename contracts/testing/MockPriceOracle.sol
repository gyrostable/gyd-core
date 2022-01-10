// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../../interfaces/IPriceOracle.sol";

contract MockPriceOracle is IPriceOracle {
    /// @inheritdoc IPriceOracle
    function getUSDValue(DataTypes.MonetaryAmount memory monetaryAmount)
        external
        pure
        override
        returns (uint256)
    {
        return monetaryAmount.amount;
    }

    /// @inheritdoc IPriceOracle
    function getUSDValue(DataTypes.MonetaryAmount[] memory monetaryAmounts)
        external
        pure
        override
        returns (uint256)
    {
        return _sumAmounts(monetaryAmounts);
    }

    function _sumAmounts(DataTypes.MonetaryAmount[] memory vaultMonetaryAmounts)
        internal
        pure
        returns (uint256)
    {
        uint256 total = 0;
        for (uint256 i = 0; i < vaultMonetaryAmounts.length; i++) {
            total += vaultMonetaryAmounts[i].amount;
        }
        return total;
    }
}
