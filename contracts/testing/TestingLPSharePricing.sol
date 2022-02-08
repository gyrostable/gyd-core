// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import "../oracles/LPSharePricing.sol";

contract TestingLPSharePricing {
    function priceBptCPMM(
        uint256[] memory weights,
        uint256 invariantDivSupply,
        uint256[] memory underlyingPrices
    ) external pure returns (uint256 bptPrice) {
        bptPrice = GyroLPSharePricing.priceBptCPMM(weights, invariantDivSupply, underlyingPrices);
    }

    function priceBptCPMMEqualWeights(
        uint256 weight,
        uint256 invariantDivSupply,
        uint256[] memory underlyingPrices
    ) external pure returns (uint256 bptPrice) {
        bptPrice = GyroLPSharePricing.priceBptCPMMEqualWeights(
            weight,
            invariantDivSupply,
            underlyingPrices
        );
    }

    function priceBptCPMMv2(
        uint256 sqrtAlpha,
        uint256 sqrtBeta,
        uint256 invariantDivSupply,
        uint256[] memory underlyingPrices
    ) external pure returns (uint256 bptPrice) {
        bptPrice = GyroLPSharePricing.priceBptCPMMv2(
            sqrtAlpha,
            sqrtBeta,
            invariantDivSupply,
            underlyingPrices
        );
    }

    function priceBptCPMMv3(
        uint256 cbrtAlpha,
        uint256 invariantDivSupply,
        uint256[] memory underlyingPrices
    ) external pure returns (uint256 bptPrice) {
        bptPrice = GyroLPSharePricing.priceBptCPMMv3(
            cbrtAlpha,
            invariantDivSupply,
            underlyingPrices
        );
    }

    function priceBptCEMM(
        GyroLPSharePricing.CEMMParams memory params,
        GyroLPSharePricing.CEMMDerivedParams memory derivedParams,
        uint256 invariantDivSupply,
        uint256[] memory underlyingPrices
    ) external pure returns (uint256 bptPrice) {
        bptPrice = GyroLPSharePricing.priceBptCEMM(
            params,
            derivedParams,
            invariantDivSupply,
            underlyingPrices
        );
    }
}
