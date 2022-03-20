// SPDX-License-Identifier: UNLICENSED
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
