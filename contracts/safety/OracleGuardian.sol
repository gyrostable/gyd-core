pragma solidity ^0.8.10;

import "../../libraries/Errors.sol";

import "../../libraries/DataTypes.sol";

contract OracleGuardian {
    uint256 public immutable safetyBlocksGuardian;

    constructor(uint256 _safetyBlocksGuardian) {
        safetyBlocksGuardian = _safetyBlocksGuardian;
    }

    // //TODO: make a whitelist of addresses that can call this and make this list settable by governance
    // function activateOracleGuardian(
    //     DataTypes.GuardedVaults[] memory vaultsToProtect,
    //     uint256 blocksToActivate
    // ) external {
    //     require(blocksToActivate <= safetyBlocksGuardian, Errors.ORACLE_GUARDIAN_TIME_LIMIT);

    //     for (uint256 i = 0; i < vaultsToProtect.length; i++) {
    //         if (
    //             vaultsToProtect[i].direction == DataTypes.Direction.In ||
    //             vaultsToProtect[i].direction == DataTypes.Direction.Both
    //         ) {
    //             flowDataBidirectionalStored[vaultsToProtect[i].vaultAddress]
    //                 .inFlow
    //                 .remainingSafetyBlocks = blocksToActivate;
    //         }
    //         if (
    //             vaultsToProtect[i].direction == DataTypes.Direction.Out ||
    //             vaultsToProtect[i].direction == DataTypes.Direction.Both
    //         ) {
    //             flowDataBidirectionalStored[vaultsToProtect[i].vaultAddress]
    //                 .outFlow
    //                 .remainingSafetyBlocks = blocksToActivate;
    //         }
    //     }
    // }
}
