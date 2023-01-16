// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../interfaces/vendor/UniswapRouter02.sol";

import "../../interfaces/oracles/IRelativePriceOracle.sol";
import "../../libraries/DecimalScale.sol";

/// @dev this is for testing purposes only as it is easy to manipulate
contract SpotRelativePriceOracle is IRelativePriceOracle {
    using DecimalScale for uint256;
    UniswapRouter02 public immutable uniswapRouter;

    constructor(UniswapRouter02 router) {
        uniswapRouter = router;
    }

    /// @inheritdoc IRelativePriceOracle
    function getRelativePrice(address baseToken, address quoteToken) public view returns (uint256) {
        address[] memory assets = new address[](2);
        assets[0] = baseToken;
        assets[1] = quoteToken;
        uint256 baseDecimals = IERC20Metadata(baseToken).decimals();
        uint8 quoteDecimals = IERC20Metadata(quoteToken).decimals();
        uint256 amountOut = uniswapRouter.getAmountsOut(10**baseDecimals, assets)[1];
        return amountOut.scaleFrom(quoteDecimals);
    }

    /// @inheritdoc IRelativePriceOracle
    function isPairSupported(address baseToken, address quoteToken) external view returns (bool) {
        try this.getRelativePrice(baseToken, quoteToken) {
            return true;
        } catch (bytes memory) {
            return false;
        }
    }
}
