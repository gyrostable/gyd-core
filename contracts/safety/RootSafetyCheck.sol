// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../../interfaces/ISafetyCheck.sol";
import "../../interfaces/IGyroConfig.sol";

import "../../libraries/EnumerableExtensions.sol";
import "../../libraries/Errors.sol";
import "../../libraries/ConfigHelpers.sol";

import "../auth/Governable.sol";

contract RootSafetyCheck is ISafetyCheck, Governable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableExtensions for EnumerableSet.AddressSet;
    using ConfigHelpers for IGyroConfig;

    event CheckAdded(address indexed check);
    event CheckRemoved(address indexed check);

    EnumerableSet.AddressSet internal _checks;

    IGyroConfig public immutable gyroConfig;

    modifier motherboardOnly() {
        require(msg.sender == address(gyroConfig.getMotherboard()), Errors.NOT_AUTHORIZED);
        _;
    }

    constructor(IGyroConfig _gyroConfig) {
        require(address(_gyroConfig) != address(0), Errors.INVALID_ARGUMENT);
        gyroConfig = _gyroConfig;
    }

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
    function isMintSafe(DataTypes.Order memory order)
        external
        view
        override
        returns (string memory err)
    {
        uint256 length = _checks.length();
        for (uint256 i = 0; i < length; i++) {
            err = ISafetyCheck(_checks.at(i)).isMintSafe(order);
            if (bytes(err).length > 0) {
                break;
            }
        }
    }

    /// @inheritdoc ISafetyCheck
    function isRedeemSafe(DataTypes.Order memory order)
        external
        view
        override
        returns (string memory err)
    {
        uint256 length = _checks.length();
        for (uint256 i = 0; i < length; i++) {
            err = ISafetyCheck(_checks.at(i)).isRedeemSafe(order);
            if (bytes(err).length > 0) {
                break;
            }
        }
    }

    /// @inheritdoc ISafetyCheck
    function checkAndPersistMint(DataTypes.Order memory order) external override motherboardOnly {
        uint256 length = _checks.length();
        for (uint256 i = 0; i < length; i++) {
            ISafetyCheck(_checks.at(i)).checkAndPersistMint(order);
        }
    }

    /// @inheritdoc ISafetyCheck
    function checkAndPersistRedeem(DataTypes.Order memory order) external override motherboardOnly {
        uint256 length = _checks.length();
        for (uint256 i = 0; i < length; i++) {
            ISafetyCheck(_checks.at(i)).checkAndPersistRedeem(order);
        }
    }
}
