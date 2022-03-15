// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../safety/VaultSafetyMode.sol";
import "../../libraries/DataTypes.sol";
import "../../libraries/StringExtensions.sol";

contract TestingVaultSafetyMode is VaultSafetyMode {
    using FixedPoint for uint256;
    using StringExtensions for string;

    constructor(
        uint256 _safetyBlocksAutomatic,
        uint256 _safetyBlocksGuardian,
        address _motherboardAddress,
        address[] memory _vaultAddresses
    )
        VaultSafetyMode(
            _safetyBlocksAutomatic,
            _safetyBlocksGuardian,
            _motherboardAddress,
            _vaultAddresses
        )
    {}

    function calculateRemainingBlocks(uint256 lastRemainingBlocks, uint256 blocksElapsed)
        external
        pure
        returns (uint256)
    {
        return _calculateRemainingBlocks(lastRemainingBlocks, blocksElapsed);
    }

    function accessDirectionalFlowData(
        address[] memory vaultAddresses,
        DataTypes.Order memory order
    )
        external
        view
        returns (
            DataTypes.DirectionalFlowData[] memory directionalFlowData,
            uint256[] memory lastSeenBlock
        )
    {
        return (_accessDirectionalFlowData(vaultAddresses, order));
    }

    function storeDirectionalFlowData(
        DataTypes.DirectionalFlowData[] memory directionalFlowData,
        DataTypes.Order memory order,
        address[] memory vaultAddresses,
        uint256 currentBlockNumber
    ) external {
        _storeDirectionalFlowData(directionalFlowData, order, vaultAddresses, currentBlockNumber);
    }

    function fetchLatestDirectionalFlowData(
        address[] memory vaultAddresses,
        uint256 currentBlockNumber,
        DataTypes.Order memory order
    ) external view returns (DataTypes.DirectionalFlowData[] memory directionalFlowData) {
        return _fetchLatestDirectionalFlowData(vaultAddresses, currentBlockNumber, order);
    }

    function updateVaultFlowSafety(
        DataTypes.DirectionalFlowData memory directionalFlowData,
        uint256 proposedFlowChange,
        uint256 shortFlowThreshold
    )
        external
        view
        returns (
            DataTypes.DirectionalFlowData memory,
            bool,
            bool
        )
    {
        return _updateVaultFlowSafety(directionalFlowData, proposedFlowChange, shortFlowThreshold);
    }

    function flowSafetyStateUpdater(DataTypes.Order memory order)
        external
        view
        returns (
            string memory,
            DataTypes.DirectionalFlowData[] memory latestDirectionalFlowData,
            address[] memory vaultAddresses,
            uint256 currentBlockNumber
        )
    {
        return _flowSafetyStateUpdater(order);
    }
}
