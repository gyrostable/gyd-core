// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.10;

import "../oracles/CheckedPriceOracle.sol";

contract TestingCheckedPriceOracle is CheckedPriceOracle {
    constructor(
        address _governor,
        IUSDPriceOracle _priceOracle,
        IRelativePriceOracle _relativeOracle
    )
        CheckedPriceOracle(
            _governor,
            address(_priceOracle),
            address(_relativeOracle),
            address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)
        )
    {}

    function ensureRootPriceGrounded(
        uint256 mainRootPrice,
        uint256[] memory signedPrices,
        uint256[] memory twaps
    ) external view {
        return _checkPriceLevel(mainRootPrice, signedPrices, twaps);
    }

    function computeMinOrSecondMin(uint256[] memory twapPrices) external pure returns (uint256) {
        return _computeMinOrSecondMin(twapPrices);
    }

    function median(uint256[] memory array) external view returns (uint256) {
        return _median(array);
    }
}
