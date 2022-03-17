// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./IMinimalPoolView.sol";

interface ICEMM is IMinimalPoolView {
    struct Params {
        int256 alpha;
        int256 beta;
        int256 c;
        int256 s;
        int256 lambda;
    }

    struct Vector2 {
        int256 x;
        int256 y;
    }

    struct DerivedParams {
        Vector2 tauAlpha;
        Vector2 tauBeta;
    }

    function getParameters() external view returns (Params memory, DerivedParams memory);
}
