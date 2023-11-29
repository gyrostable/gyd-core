// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "./BaseVault.sol";
import "../../libraries/ConfigHelpers.sol";
import "../../interfaces/oracles/IRateManager.sol";

contract GenericVault is BaseVault {
    using ConfigHelpers for IGyroConfig;

    constructor(address _config) BaseVault(_config) {}

    function initialize(
        address _underlying,
        address governor,
        string memory name,
        string memory symbol
    ) external virtual initializer {
        __BaseVault_initialize(_underlying, governor, name, symbol);
    }

    /// @inheritdoc IGyroVault
    function vaultType() external view virtual override returns (Vaults.Type) {
        return Vaults.Type.GENERIC;
    }

    /// @inheritdoc IGyroVault
    function getTokens() external view virtual override returns (IERC20[] memory) {
        IERC20[] memory tokens = new IERC20[](1);
        IRateManager.RateProviderInfo memory providerInfo = gyroConfig
            .getRateManager()
            .getProviderInfo(underlying);
        if (providerInfo.underlying != address(0)) {
            tokens[0] = IERC20(providerInfo.underlying);
        } else {
            tokens[0] = IERC20(underlying);
        }
        return tokens;
    }
}
