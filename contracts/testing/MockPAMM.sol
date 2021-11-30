// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

import "../../interfaces/IPAMM.sol";

contract MockPAMM is IPAMM {
    /// @inheritdoc IPAMM
    function calculateGYDToMint(DataTypes.MonetaryAmount[] memory vaultMonetaryAmounts, uint256)
        external
        pure
        override
        returns (uint256 gydAmount)
    {
        return _sumAmounts(vaultMonetaryAmounts);
    }

    /// @inheritdoc IPAMM
    function calculateAndRecordGYDToMint(
        DataTypes.MonetaryAmount[] memory vaultMonetaryAmounts,
        uint256
    ) external pure override returns (uint256 gydAmount) {
        return _sumAmounts(vaultMonetaryAmounts);
    }

    /// @inheritdoc IPAMM
    function calculateGYDToBurn(DataTypes.MonetaryAmount[] memory vaultMonetaryAmounts, uint256)
        external
        pure
        override
        returns (uint256 gydAmount)
    {
        return _sumAmounts(vaultMonetaryAmounts);
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
