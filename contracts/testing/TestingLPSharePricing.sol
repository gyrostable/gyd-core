// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
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

    function priceBptTwoAssetCPMM(
        uint256[] memory weights,
        uint256 invariantDivSupply,
        uint256[] memory underlyingPrices
    ) external pure returns (uint256 bptPrice) {
        bptPrice = BalancerLPSharePricing.priceBptTwoAssetCPMM(
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

    function priceBpt2CLP(
        uint256 sqrtAlpha,
        uint256 sqrtBeta,
        uint256 invariantDivSupply,
        uint256[] memory underlyingPrices
    ) external pure returns (uint256 bptPrice) {
        bptPrice = BalancerLPSharePricing.priceBpt2CLP(
            sqrtAlpha,
            sqrtBeta,
            invariantDivSupply,
            underlyingPrices
        );
    }

    function priceBpt3CLP(
        uint256 cbrtAlpha,
        uint256 invariantDivSupply,
        uint256[] memory underlyingPrices
    ) external pure returns (uint256 bptPrice) {
        bptPrice = BalancerLPSharePricing.priceBpt3CLP(
            cbrtAlpha,
            invariantDivSupply,
            underlyingPrices
        );
    }

    function relativeEquilibriumPrices3CLP(
        uint256 alpha,
        uint256 pXZ,
        uint256 pYZ
    ) external pure returns (uint256, uint256) {
        return BalancerLPSharePricing.relativeEquilibriumPrices3CLP(alpha, pXZ, pYZ);
    }

    function priceBptECLP(
        IECLP.Params memory params,
        IECLP.DerivedParams memory derivedParams,
        uint256 invariantDivSupply,
        uint256[] memory underlyingPrices
    ) external pure returns (uint256 bptPrice) {
        bptPrice = BalancerLPSharePricing.priceBptECLP(
            params,
            derivedParams,
            invariantDivSupply,
            underlyingPrices
        );
    }
}
