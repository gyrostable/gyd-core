// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../ReserveSafetyManager.sol";

contract TestingReserveSafetyManager is ReserveSafetyManager {
    constructor(uint256 _maxAllowedVaultDeviation, address _balancerSafetyChecks)
        ReserveSafetyManager(_maxAllowedVaultDeviation, _balancerSafetyChecks)
    {}

    function wouldVaultsRemainBalanced(DataTypes.VaultInfo[] memory vaults)
        external
        view
        returns (bool)
    {
        return _wouldVaultsRemainBalanced(vaults);
    }

    function wouldVaultsBeRebalancing(DataTypes.VaultInfo[] memory vaults)
        external
        view
        returns (bool)
    {
        return _wouldVaultsBeRebalancing(vaults);
    }
}
