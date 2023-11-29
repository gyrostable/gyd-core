// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "./BaseVaultPriceOracle.sol";
import "../../interfaces/IGyroConfig.sol";
import "../../libraries/ConfigHelpers.sol";

contract GenericVaultPriceOracle is BaseVaultPriceOracle {
    using FixedPoint for uint256;
    using ConfigHelpers for IGyroConfig;

    IGyroConfig public immutable gyroConfig;

    constructor(address _config) {
        gyroConfig = IGyroConfig(_config);
    }

    /// @inheritdoc BaseVaultPriceOracle
    function getPoolTokenPriceUSD(
        IGyroVault vault,
        DataTypes.PricedToken[] memory underlyingPricedTokens
    ) public view override returns (uint256) {
        DataTypes.PricedToken memory pricedToken = underlyingPricedTokens[0];
        uint256 underlyingPrice = pricedToken.price;
        address vaultToken = vault.underlying(); // could be sDAI
        (address underlyingToken, uint256 rate) = gyroConfig.getRateManager().getUnderlyingAndRate(
            vaultToken
        );
        require(
            underlyingToken == pricedToken.tokenAddress,
            "GenericVaultPriceOracle: token mismatch"
        );
        return underlyingPrice.mulDown(rate);
    }
}
