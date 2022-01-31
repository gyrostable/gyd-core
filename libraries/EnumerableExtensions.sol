// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

library EnumerableExtensions {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    using EnumerableMap for EnumerableMap.UintToAddressMap;

    function toArray(EnumerableSet.AddressSet storage values)
        internal
        view
        returns (address[] memory)
    {
        uint256 len = values.length();
        address[] memory result = new address[](len);
        for (uint256 i = 0; i < len; i++) {
            result[i] = values.at(i);
        }
        return result;
    }

    function toArray(EnumerableSet.Bytes32Set storage values)
        internal
        view
        returns (bytes32[] memory)
    {
        uint256 len = values.length();
        bytes32[] memory result = new bytes32[](len);
        for (uint256 i = 0; i < len; i++) {
            result[i] = values.at(i);
        }
        return result;
    }

    function keysArray(EnumerableMap.UintToAddressMap storage map)
        internal
        view
        returns (bytes32[] memory)
    {
        return toArray(map._inner._keys);
    }

    function valuesArray(EnumerableMap.UintToAddressMap storage map)
        internal
        view
        returns (address[] memory)
    {
        address[] memory result = new address[](map.length());
        uint256 length = map.length();
        for (uint256 i = 0; i < length; i++) {
            (, result[i]) = map.at(i);
        }
        return result;
    }
}
