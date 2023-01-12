// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "../oracles/TrustedSignerPriceOracle.sol";

contract TestingTrustedSignerPriceOracle is TrustedSignerPriceOracle {
    constructor(
        address _assetRegistry,
        address _priceSigner,
        bool _preventStalePrice
    ) TrustedSignerPriceOracle(_assetRegistry, _priceSigner, _preventStalePrice) {}

    function callVerifyMessage(bytes memory message, bytes memory signature)
        external
        pure
        returns (address)
    {
        return verifyMessage(message, signature);
    }

    function callDecodeMessage(bytes memory message)
        external
        pure
        returns (
            uint256,
            string memory,
            uint256
        )
    {
        return decodeMessage(message);
    }
}
