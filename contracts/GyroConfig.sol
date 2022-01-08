// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../interfaces/IGyroConfig.sol";
import "./auth/Governable.sol";

contract GyroConfig is IGyroConfig, Governable {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    mapping(bytes32 => uint256) _configUInts;
    mapping(bytes32 => address) _configAddresses;

    EnumerableSet.Bytes32Set _knownConfigKeys;

    constructor() Governable() {}

    /// @inheritdoc IGyroConfig
    function listKeys() external view override returns (bytes32[] memory) {
        uint256 length = _knownConfigKeys.length();
        bytes32[] memory keys = new bytes32[](length);
        for (uint256 i = 0; i < length; i++) {
            keys[i] = _knownConfigKeys.at(i);
        }
        return keys;
    }

    /// @inheritdoc IGyroConfig
    function getUint(bytes32 key) external view override returns (uint256) {
        return _configUInts[key];
    }

    /// @inheritdoc IGyroConfig
    function getAddress(bytes32 key) external view override returns (address) {
        return _configAddresses[key];
    }

    /// @inheritdoc IGyroConfig
    function setUint(bytes32 key, uint256 newValue) external override governanceOnly {
        uint256 oldValue = _configUInts[key];
        _configUInts[key] = newValue;
        _knownConfigKeys.add(key);
        emit ConfigChanged(key, oldValue, newValue);
    }

    /// @inheritdoc IGyroConfig
    function setAddress(bytes32 key, address newValue) external override governanceOnly {
        address oldValue = _configAddresses[key];
        _configAddresses[key] = newValue;
        _knownConfigKeys.add(key);
        emit ConfigChanged(key, oldValue, newValue);
    }
}
