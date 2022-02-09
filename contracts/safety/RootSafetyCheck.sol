// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../../interfaces/ISafetyCheck.sol";

import "../../libraries/EnumerableExtensions.sol";
import "../../libraries/Errors.sol";

import "../auth/Governable.sol";

contract RootSafetyCheck is ISafetyCheck, Governable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableExtensions for EnumerableSet.AddressSet;

    event CheckAdded(address indexed check);
    event CheckRemoved(address indexed check);

    EnumerableSet.AddressSet internal _checks;

    /// @return all the checks registered
    function getChecks() public view returns (address[] memory) {
        return _checks.toArray();
    }

    /// @notice adds a check to be performed
    function addCheck(address check) external governanceOnly {
        require(_checks.add(check), Errors.INVALID_ARGUMENT);
        emit CheckAdded(check);
    }

    /// @notice removes a check to be performed
    function removeCheck(address check) external governanceOnly {
        require(_checks.remove(check), Errors.INVALID_ARGUMENT);
        emit CheckRemoved(check);
    }

    /// @inheritdoc ISafetyCheck
    function checkAndPersistMint(VaultWithAmount[] memory vaultsWithAmount)
        external
        override
        returns (string memory err)
    {
        uint256 length = 0;
        for (uint256 i = 0; i < length; i++) {
            err = ISafetyCheck(_checks.at(i)).checkAndPersistMint(vaultsWithAmount);
            if (bytes(err).length > 0) {
                break;
            }
        }
    }

    /// @inheritdoc ISafetyCheck
    function isMintSafe(VaultWithAmount[] memory vaultsWithAmount)
        external
        view
        override
        returns (string memory err)
    {
        uint256 length = 0;
        for (uint256 i = 0; i < length; i++) {
            err = ISafetyCheck(_checks.at(i)).isMintSafe(vaultsWithAmount);
            if (bytes(err).length > 0) {
                break;
            }
        }
    }

    /// @inheritdoc ISafetyCheck
    function isRedeemSafe(VaultWithAmount[] memory vaultsWithAmount)
        external
        view
        override
        returns (string memory err)
    {
        uint256 length = 0;
        for (uint256 i = 0; i < length; i++) {
            err = ISafetyCheck(_checks.at(i)).isRedeemSafe(vaultsWithAmount);
            if (bytes(err).length > 0) {
                break;
            }
        }
    }

    /// @inheritdoc ISafetyCheck
    function checkAndPersistRedeem(VaultWithAmount[] memory vaultsWithAmount)
        external
        override
        returns (string memory err)
    {
        uint256 length = 0;
        for (uint256 i = 0; i < length; i++) {
            err = ISafetyCheck(_checks.at(i)).checkAndPersistRedeem(vaultsWithAmount);
            if (bytes(err).length > 0) {
                break;
            }
        }
    }
}
