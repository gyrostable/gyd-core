// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "../libraries/Errors.sol";

library Arrays {
    function sort(address[] memory data) internal view returns (address[] memory) {
        if (data.length == 0) return data;
        _sort(data, int256(0), int256(data.length - 1));
        return data;
    }

    function _sort(
        address[] memory arr,
        int256 left,
        int256 right
    ) internal view {
        int256 i = left;
        int256 j = right;
        if (i == j) return;
        address pivot = arr[uint256(left + (right - left) / 2)];
        while (i <= j) {
            while (arr[uint256(i)] < pivot) i++;
            while (pivot < arr[uint256(j)]) j--;
            if (i <= j) {
                (arr[uint256(i)], arr[uint256(j)]) = (arr[uint256(j)], arr[uint256(i)]);
                i++;
                j--;
            }
        }
        if (left < j) _sort(arr, left, j);
        if (i < right) _sort(arr, i, right);
    }

    function dedup(address[] memory data) internal pure returns (address[] memory) {
        uint256 duplicatedCount = 0;
        for (uint256 i = 1; i < data.length; i++) {
            if (data[i - 1] == data[i]) duplicatedCount++;
        }
        if (duplicatedCount == 0) return data;
        address[] memory deduped = new address[](data.length - duplicatedCount);
        for ((uint256 i, uint256 j) = (0, 0); i < data.length; i++) {
            if (i < data.length - 1 && data[i] == data[i + 1]) continue;
            deduped[j] = data[i];
            j++;
        }
        return deduped;
    }
}
