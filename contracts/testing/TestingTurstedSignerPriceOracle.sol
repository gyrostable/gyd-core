// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../oracles/TrustedSignerPriceOracle.sol";

contract TestingTrustedSignerPriceOracle is TrustedSignerPriceOracle {
    constructor(address _assetRegistry, address _priceSigner)
        TrustedSignerPriceOracle(_assetRegistry, _priceSigner)
    {}

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