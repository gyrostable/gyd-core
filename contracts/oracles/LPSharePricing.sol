// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../../libraries/FixedPoint.sol";
import "../../libraries/SignedFixedPoint.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

library GyroLPSharePricing {
    using FixedPoint for uint256;
    using SignedFixedPoint for int256;
    using SafeCast for uint256;
    using SafeCast for int256;

    uint256 internal constant ONEHALF = 0.5e18;

    /** @dev Calculates the value of Balancer pool tokens (BPT) that use constant product invariant
     *  @param weights = weights of underlying assets
     *  @param underlyingPrices = prices of underlying assets, in same order as weights
     *  @param invariantDivSupply = value of the pool invariant / supply of BPT
     *  This calculation is robust to price manipulation within the Balancer pool */
    function priceBptCPMM(
        uint256[] memory weights,
        uint256 invariantDivSupply,
        uint256[] memory underlyingPrices
    ) internal pure returns (uint256 bptPrice) {
        /**********************************************************************************************
        //                        L   n               w_i                               //
        //            bptPrice = ---  Π   (p_i / w_i)^                                  //
        //                        S   i=1                                               //
        **********************************************************************************************/
        bptPrice = invariantDivSupply;
        uint256 term = FixedPoint.ONE;
        for (uint256 i = 0; i < weights.length; i++) {
            term = term.mulDown(
                FixedPoint.powDown(underlyingPrices[i].divDown(weights[i]), weights[i])
            );
            bptPrice = bptPrice.mulDown(term);
        }
    }

    /** @dev Calculates value of BPT for constant product invariant with equal weights
     *  Compared to general CPMM, everything can be grouped into one fractional power to save gas */
    function priceBptCPMMEqualWeights(
        uint256 weight,
        uint256 invariantDivSupply,
        uint256[] memory underlyingPrices
    ) internal pure returns (uint256 bptPrice) {
        /**********************************************************************************************
        //                        L     n             w                                 //
        //            bptPrice = ---  ( Π   p_i / w )^                                  //
        //                        S     i=1                                             //
        **********************************************************************************************/
        bptPrice = invariantDivSupply;
        uint256 term = FixedPoint.ONE;
        for (uint256 i = 0; i < underlyingPrices.length; i++) {
            term = term.mulDown(underlyingPrices[i].divDown(weight));
        }
        term = FixedPoint.powDown(term, weight);
        bptPrice = bptPrice.mulDown(term);
    }

    /** @dev Calculates the value of BPT for CPMMv2 pools
     *  these are constant product invariant 2-pools with 1/2 weights and virtual reserves
     *  @param sqrtAlpha = sqrt of lower price bound
     *  @param sqrtBeta = sqrt of upper price bound
     *  @param invariantDivSupply = value of the pool invariant / supply of BPT
     *  This calculation is robust to price manipulation within the Balancer pool */
    function priceBptCPMMv2(
        uint256 sqrtAlpha,
        uint256 sqrtBeta,
        uint256 invariantDivSupply,
        uint256[] memory underlyingPrices
    ) internal pure returns (uint256 bptPrice) {
        /**********************************************************************************************
        //                 L                 1/2               1/2              1/2     //
        //     bptPrice = ---  ( 2 (p_x p_y)^     - p_x / beta^     - p_y alpha^    )   //
        //                 S                                                            //
        **********************************************************************************************/
        uint256 sqrtPxPy = underlyingPrices[0].mulDown(underlyingPrices[1]);
        sqrtPxPy = FixedPoint.powDown(sqrtPxPy, ONEHALF);
        bptPrice = 2 * FixedPoint.ONE.mulDown(sqrtPxPy);
        bptPrice = bptPrice - underlyingPrices[0].divUp(sqrtBeta);
        bptPrice = bptPrice - underlyingPrices[1].mulUp(sqrtAlpha);
        bptPrice = bptPrice.mulDown(invariantDivSupply);
    }

    /** @dev Calculates the value of BPT for CPMMv3 pools
     *  these are constant product invariant 3-pools with 1/3 weights and virtual reserves
     *  virtual reserves are chosen such that alpha = lower price bound and 1/alpha = upper price bound
     *  @param cbrtAlpha = cube root of alpha (lower price bound)
     *  @param invariantDivSupply = value of the pool invariant / supply of BPT
     *  This calculation is robust to price manipulation within the Balancer pool */
    function priceBptCPMMv3(
        uint256 cbrtAlpha,
        uint256 invariantDivSupply,
        uint256[] memory underlyingPrices
    ) internal pure returns (uint256 bptPrice) {
        /**********************************************************************************************
        //                 L                     1/3                            1/3     //
        //     bptPrice = ---  ( 3 (p_x p_y p_z)^     - (p_x + p_y + p_z) alpha^    )   //
        //                 S                                                            //
        **********************************************************************************************/
        uint256 cbrtPxPyPz = underlyingPrices[0].mulDown(underlyingPrices[1]).mulDown(
            underlyingPrices[2]
        );
        cbrtPxPyPz = FixedPoint.powDown(cbrtPxPyPz, FixedPoint.ONE / 3);
        bptPrice = 3 * FixedPoint.ONE.mulDown(cbrtPxPyPz);
        uint256 term = (underlyingPrices[0] + underlyingPrices[1] + underlyingPrices[2]).mulUp(
            cbrtAlpha
        );
        bptPrice = bptPrice - term;
        bptPrice = bptPrice.mulDown(invariantDivSupply);
    }

    /** @dev Calculates the value of BPT for constant ellipse (CEMM) pools of two assets
     *  @param params = CEMM pool parameters
     *  @param derivedParams = (tau(alpha), tau(beta))
     *  @param invariantDivSupply = value of the pool invariant / supply of BPT
     *  This calculation is robust to price manipulation within the Balancer pool */
    function priceBptCEMM(
        CEMMParams memory params,
        CEMMDerivedParams memory derivedParams,
        uint256 invariantDivSupply,
        uint256[] memory underlyingPrices
    ) internal pure returns (uint256 bptPrice) {
        /**********************************************************************************************
        //                L   / / e_x A^{-1} tau(beta) \     -1     / p_x \  \   / p_x \             //
        //   bptPrice =  --- | |                        | - A^  tau|  ---- |  | |       |            //
        //                S   \ \ e_y A^{-1} tau(alpha) /           \ p_y  /  /  \ p_y  /            //
        **********************************************************************************************/
        int256 px = underlyingPrices[0].divDown(underlyingPrices[1]).toInt256();
        Vector2 memory vec = mulAinv(params, tau(params, px));
        vec.x = mulAinv(params, derivedParams.tauBeta).x - vec.x;
        vec.y = mulAinv(params, derivedParams.tauAlpha).y - vec.y;

        Vector2 memory prices;
        prices.x = underlyingPrices[0].toInt256();
        prices.y = underlyingPrices[1].toInt256();
        bptPrice = scalarProdDown(prices, vec).toUint256();
        bptPrice = bptPrice.mulDown(invariantDivSupply);
    }

    ///////////////////////////////////////////////////////////////////////////////////////
    // The following functions and structs copied over from CEMM math library
    // Can't easily inherit because of different Solidity versions

    struct CEMMParams {
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

    struct CEMMDerivedParams {
        Vector2 tauAlpha;
        Vector2 tauBeta;
    }

    // Scalar product of Vector2 objects
    function scalarProdDown(Vector2 memory t1, Vector2 memory t2)
        internal
        pure
        returns (int256 ret)
    {
        ret = t1.x.mulDown(t2.x).add(t1.y.mulDown(t2.y));
    }

    /** @dev Calculate A^{-1}t where A^{-1} is given in Section 2.2
     *  This is rotating and scaling the circle into the ellipse */
    function mulAinv(CEMMParams memory params, Vector2 memory t)
        internal
        pure
        returns (Vector2 memory tp)
    {
        tp.x = params.c.mulDown(params.lambda).mulDown(t.x);
        tp.x = tp.x.add(params.s.mulDown(t.y));
        tp.y = (-params.s).mulDown(params.lambda).mulDown(t.x);
        tp.y = tp.y.add(params.c.mulDown(t.y));
    }

    /** @dev Calculate A t where A is given in Section 2.2
     *  This is reversing rotation and scaling of the ellipse (mapping back to circle) */
    function mulA(CEMMParams memory params, Vector2 memory tp)
        internal
        pure
        returns (Vector2 memory t)
    {
        t.x = params.c.divDown(params.lambda).mulDown(tp.x);
        t.x = t.x.sub(params.s.divDown(params.lambda).mulDown(tp.y));
        t.y = params.s.mulDown(tp.x);
        t.y = t.y.add(params.c.mulDown(tp.y));
    }

    /** @dev Given price px on the transformed ellipse, get the untransformed price pxc on the circle
     *  px = price of asset x in terms of asset y */
    function zeta(CEMMParams memory params, int256 px) internal pure returns (int256 pxc) {
        Vector2 memory nd = mulA(params, Vector2(-SignedFixedPoint.ONE, px));
        return -nd.y.divDown(nd.x);
    }

    /** @dev Given price px on the transformed ellipse, maps to the corresponding point on the untransformed normalized circle
     *  px = price of asset x in terms of asset y */
    function tau(CEMMParams memory params, int256 px) internal pure returns (Vector2 memory tpp) {
        return eta(zeta(params, px));
    }

    /** @dev Given price on a circle, gives the normalized corresponding point on the circle centered at the origin
     *  pxc = price of asset x in terms of asset y (measured on the circle)
     *  Notice that the eta function does not depend on Params */
    function eta(int256 pxc) internal pure returns (Vector2 memory tpp) {
        int256 z = FixedPoint
            .powDown(FixedPoint.ONE + (pxc.mulDown(pxc).toUint256()), ONEHALF)
            .toInt256();
        tpp = eta(pxc, z);
    }

    /** @dev Calculates eta in more efficient way if the square root is known and input as second arg */
    function eta(int256 pxc, int256 z) internal pure returns (Vector2 memory tpp) {
        tpp.x = pxc.divDown(z);
        tpp.y = SignedFixedPoint.ONE.divDown(z);
    }
}
