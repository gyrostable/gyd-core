// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.

pragma solidity ^0.8.4;

import "../../interfaces/IPAMM.sol";
import "../../libraries/FixedPoint.sol";

contract PAMMWrongRedeemQuote is IPAMM {
    using FixedPoint for uint256;

    function computeMintAmount(
        uint256 usdAmount,
        uint256 /* reserveUSDValue */
    ) external pure returns (uint256) {
        return usdAmount;
    }

    function mint(
        uint256 usdAmount,
        uint256 /* reserveUSDValue */
    ) external pure returns (uint256) {
        return usdAmount;
    }

    function computeRedeemAmount(
        uint256 gydAmount,
        uint256 /* reserveUSDValue */
    ) external pure returns (uint256) {
        return gydAmount.mulDown(1.001e18);
    }

    function redeem(
        uint256 gydAmount,
        uint256 /* reserveUSDValue */
    ) external pure returns (uint256) {
        return gydAmount.mulDown(1.001e18);
    }

    function setSystemParams(Params memory params) external {}

    function systemParams() external view returns (Params memory) {}
}
