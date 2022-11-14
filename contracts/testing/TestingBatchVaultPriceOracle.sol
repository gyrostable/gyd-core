// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "../oracles/BatchVaultPriceOracle.sol";

contract TestingBatchVaultPriceOracle is BatchVaultPriceOracle {
    constructor(IUSDBatchPriceOracle _batchPriceOracle) BatchVaultPriceOracle(_batchPriceOracle) {}

    function constructTokensArray(DataTypes.VaultInfo[] memory vaultsInfo)
        external
        view
        returns (address[] memory)
    {
        return _constructTokensArray(vaultsInfo);
    }
}
