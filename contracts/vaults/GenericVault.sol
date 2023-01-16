// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "./BaseVault.sol";

contract GenericVault is BaseVault {
    constructor(
        address _governor,
        address _underlying,
        string memory name,
        string memory symbol
    ) BaseVault(_governor, _underlying, name, symbol) {}

    /// @inheritdoc IGyroVault
    function vaultType() external view virtual override returns (Vaults.Type) {
        return Vaults.Type.GENERIC;
    }

    /// @inheritdoc IGyroVault
    function getTokens() external view virtual override returns (IERC20[] memory) {
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(underlying);
        return tokens;
    }
}
