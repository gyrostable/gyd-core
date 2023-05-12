// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "../../interfaces/oracles/IUSDPriceOracle.sol";
import "@usingtellor/contracts/UsingTellor.sol";

import "../../libraries/Errors.sol";

contract TellorOracle is IUSDPriceOracle, UsingTellor {
    address public immutable wethAddress;
    bytes32 internal immutable queryId;

    constructor(address payable _tellorAddress, address _wethAddress) UsingTellor(_tellorAddress) {
        wethAddress = _wethAddress;
        bytes memory _queryData = abi.encode("SpotPrice", abi.encode("eth", "usd"));
        queryId = keccak256(_queryData);
    }

    function getPriceUSD(address tokenAddress) external view returns (uint256) {
        require(tokenAddress == wethAddress, Errors.ASSET_NOT_SUPPORTED);
        (bytes memory _value, uint256 _timestampRetrieved) = getDataBefore(
            queryId,
            block.timestamp - 10 minutes
        );
        require(_timestampRetrieved > 0, Errors.STALE_PRICE);
        require(block.timestamp - _timestampRetrieved < 24 hours, Errors.STALE_PRICE);
        return abi.decode(_value, (uint256));
    }
}
