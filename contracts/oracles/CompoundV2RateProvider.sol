// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../libraries/DecimalScale.sol";
import "../../interfaces/oracles/IRateProvider.sol";

interface ICToken {
    function underlying() external view returns (address);

    function exchangeRateStored() external view returns (uint256);

    function decimals() external view returns (uint8);
}

/// @notice This is used for Compound V2 or Flux tokens
contract CompoundV2RateProvider is IRateProvider {
    using DecimalScale for uint256;

    ICToken public immutable cToken;
    uint8 public immutable rateDecimals;

    constructor(ICToken _cToken) {
        cToken = _cToken;
        rateDecimals = 18 + IERC20Metadata(_cToken.underlying()).decimals() - _cToken.decimals();
    }

    function getRate() external view override returns (uint256) {
        uint256 exchangeRate = cToken.exchangeRateStored();
        return exchangeRate.scaleFrom(rateDecimals);
    }
}
