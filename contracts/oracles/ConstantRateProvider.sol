// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "../../interfaces/oracles/IRateProvider.sol";

/// @notice This is used for tokens such as aTokens where assets are wrapped
/// in a token where the rate is always the same
contract ConstantRateProvider is IRateProvider {
    uint256 internal immutable _rate;

    constructor(uint256 rate) {
        _rate = rate;
    }

    function getRate() external view override returns (uint256) {
        return _rate;
    }
}
