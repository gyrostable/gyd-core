// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import "../oracles/balancer/BalancerLPSharePricing.sol";

contract TestingLPSharePricing {
    function priceBptCPMM(
        uint256[] memory weights,
        uint256 invariantDivSupply,
        uint256[] memory underlyingPrices
    ) external pure returns (uint256 bptPrice) {
        bptPrice = BalancerLPSharePricing.priceBptCPMM(
            weights,
            invariantDivSupply,
            underlyingPrices
        );
    }

    function priceBptCPMMEqualWeights(
        uint256 weight,
        uint256 invariantDivSupply,
        uint256[] memory underlyingPrices
    ) external pure returns (uint256 bptPrice) {
        bptPrice = BalancerLPSharePricing.priceBptCPMMEqualWeights(
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
        bptPrice = BalancerLPSharePricing.priceBptCPMMv2(
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
        bptPrice = BalancerLPSharePricing.priceBptCPMMv3(
            cbrtAlpha,
            invariantDivSupply,
            underlyingPrices
        );
    }

    function priceBptCEMM(
        ICEMM.Params memory params,
        ICEMM.DerivedParams memory derivedParams,
        uint256 invariantDivSupply,
        uint256[] memory underlyingPrices
    ) external pure returns (uint256 bptPrice) {
        bptPrice = BalancerLPSharePricing.priceBptCEMM(
            params,
            derivedParams,
            invariantDivSupply,
            underlyingPrices
        );
    }
}
