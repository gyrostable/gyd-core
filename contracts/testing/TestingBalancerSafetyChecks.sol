// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../BalancerSafetyChecks.sol";

contract TestingBalancerSafetyChecks is BalancerSafetyChecks {
    constructor(
        address _balancerVaultAddress,
        address _assetRegistryAddress,
        address _priceOracleAddress,
        address _assetPricerAddress,
        uint256 _maxActivityLag,
        uint256 _stablecoinMaxDeviation,
        uint256 _poolWeightMaxDeviation
    )
        BalancerSafetyChecks(
            _balancerVaultAddress,
            _assetRegistryAddress,
            _priceOracleAddress,
            _assetPricerAddress,
            _maxActivityLag,
            _stablecoinMaxDeviation,
            _poolWeightMaxDeviation
        )
    {}

    function makeMonetaryAmounts(IERC20[] memory _tokens, uint256[] memory _balances)
        external
        pure
        returns (DataTypes.MonetaryAmount[] memory)
    {
        return _makeMonetaryAmounts(_tokens, _balances);
    }

    function computeActualWeights(DataTypes.MonetaryAmount[] memory monetaryAmounts)
        external
        view
        returns (uint256[] memory)
    {
        return _computeActualWeights(monetaryAmounts);
    }
}
