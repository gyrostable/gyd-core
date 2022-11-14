// SPDX-License-Identifier: for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>. 
pragma solidity ^0.8.4;

import "../../oracles/TrustedSignerPriceOracle.sol";

contract TrustedSignerPriceOracleProfiler is TrustedSignerPriceOracle {
    TrustedSignerPriceOracle internal oracle;

    constructor(address _assetRegistry, address _priceSigner)
        TrustedSignerPriceOracle(_assetRegistry, _priceSigner)
    {}

    function profilePostPrice(TrustedSignerPriceOracle.SignedPrice[] calldata signedPrices)
        external
    {
        for (uint256 i = 0; i < signedPrices.length; i++) {
            TrustedSignerPriceOracle.SignedPrice calldata signedPrice = signedPrices[i];
            this.postPrice(signedPrice.message, signedPrice.signature);
        }
    }
}
