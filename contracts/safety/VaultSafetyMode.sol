// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./../auth/Governable.sol";
import "../../libraries/DataTypes.sol";
import "../../interfaces/IVaultManager.sol";
import "../../interfaces/IAssetRegistry.sol";
import "../../interfaces/IGyroVault.sol";
import "../../interfaces/balancer/IVault.sol";
import "../../libraries/Errors.sol";
import "../../interfaces/ISafetyCheck.sol";
import "../../interfaces/IVaultRegistry.sol";
import "../../libraries/FixedPoint.sol";
import "../../libraries/Flow.sol";

contract VaultSafetyMode is ISafetyCheck, Governable {
    using FixedPoint for uint256;

    event SafetyStatus(string err);

    mapping(address => DataTypes.FlowData) public flowDataBidirectionalStored;

    uint256 public immutable safetyBlocksAutomatic;
    uint256 public immutable safetyBlocksGuardian;

    uint256 public constant THRESHOLD_BUFFER = 8e17;

    constructor(uint256 _safetyBlocksAutomatic, uint256 _safetyBlocksGuardian) {
        safetyBlocksAutomatic = _safetyBlocksAutomatic;
        safetyBlocksGuardian = _safetyBlocksGuardian;
    }

    function calculateRemainingBlocks(uint256 lastRemainingBlocks, uint256 blocksElapsed)
        internal
        pure
        returns (uint256)
    {
        if (blocksElapsed >= lastRemainingBlocks) {
            return 0;
        } else {
            return (lastRemainingBlocks - blocksElapsed);
        }
    }

    //TODO: gas optimize this
    function storeDirectionalFlowData(
        DataTypes.DirectionalFlowData[] memory directionalFlowData,
        DataTypes.Order memory order,
        address[] memory vaultAddresses
    ) private {
        if (order.mint) {
            for (uint256 i = 0; i < directionalFlowData.length; i++) {
                flowDataBidirectionalStored[vaultAddresses[i]].inFlow = directionalFlowData[i];
            }
        } else {
            for (uint256 i = 0; i < directionalFlowData.length; i++) {
                flowDataBidirectionalStored[vaultAddresses[i]].outFlow = directionalFlowData[i];
            }
        }
    }

    //TODO: gas optimize this. The parameters for this contract could also potentially be packed here.
    function accessDirectionalFlowData(
        address[] memory vaultAddresses,
        DataTypes.Order memory order
    )
        private
        view
        returns (
            DataTypes.DirectionalFlowData[] memory directionalFlowData,
            uint256[] memory lastSeenBlock
        )
    {
        if (order.mint) {
            for (uint256 i = 0; i < vaultAddresses.length; i++) {
                directionalFlowData[i] = flowDataBidirectionalStored[vaultAddresses[i]].inFlow;
                lastSeenBlock[i] = flowDataBidirectionalStored[vaultAddresses[i]].lastSeenBlock;
            }
        } else {
            for (uint256 i = 0; i < vaultAddresses.length; i++) {
                directionalFlowData[i] = flowDataBidirectionalStored[vaultAddresses[i]].outFlow;
                lastSeenBlock[i] = flowDataBidirectionalStored[vaultAddresses[i]].lastSeenBlock;
            }
        }
    }

    function initializeVaultFlowData(
        address[] memory vaultAddresses,
        uint256 currentBlockNumber,
        DataTypes.Order memory order
    )
        internal
        view
        returns (
            DataTypes.DirectionalFlowData[] memory directionalFlowData,
            uint256[] memory lastSeenBlock
        )
    {
        (directionalFlowData, lastSeenBlock) = accessDirectionalFlowData(vaultAddresses, order);

        for (uint256 i = 0; i < directionalFlowData.length; i++) {
            uint256 blocksElapsed = currentBlockNumber - lastSeenBlock[i];

            directionalFlowData[i].remainingSafetyBlocks = calculateRemainingBlocks(
                directionalFlowData[i].remainingSafetyBlocks,
                blocksElapsed
            );

            directionalFlowData[i].shortFlow = Flow.updateFlow(
                directionalFlowData[i].shortFlow,
                currentBlockNumber,
                lastSeenBlock[i],
                order.vaultsWithAmount[i].vaultInfo.persistedMetadata.shortFlowMemory
            );

            // lastSeenBlock[i] = currentBlockNumber;
        }
    }

    // TODO: emit events when a safety mode is activated
    function updateVaultFlowSafety(
        DataTypes.DirectionalFlowData memory directionalFlowData,
        uint256 proposedFlowChange,
        uint256 shortFlowThreshold
    )
        private
        view
        returns (
            DataTypes.DirectionalFlowData memory,
            bool,
            bool
        )
    {
        bool allowTransaction = true;
        bool isSafetyModeActivated = false;

        if (directionalFlowData.remainingSafetyBlocks > 0) {
            return (directionalFlowData, false, true);
        }
        uint256 newFlow = directionalFlowData.shortFlow + proposedFlowChange;
        if (newFlow > shortFlowThreshold) {
            allowTransaction = false;
            directionalFlowData.remainingSafetyBlocks = safetyBlocksAutomatic;
        } else if (newFlow > THRESHOLD_BUFFER.mulDown(shortFlowThreshold)) {
            directionalFlowData.remainingSafetyBlocks = safetyBlocksAutomatic;
            directionalFlowData.shortFlow += newFlow;
            isSafetyModeActivated = true;
        } else {
            directionalFlowData.shortFlow += newFlow;
        }

        return (directionalFlowData, allowTransaction, isSafetyModeActivated);
    }

    function flowSafetyStateUpdater(DataTypes.Order memory order)
        internal
        returns (
            string memory,
            DataTypes.DirectionalFlowData[] memory latestDirectionalFlowData,
            address[] memory vaultAddresses
        )
    {
        uint256 currentBlockNumber = block.number;

        for (uint256 i = 0; i < order.vaultsWithAmount.length; i++) {
            vaultAddresses[i] = order.vaultsWithAmount[i].vaultInfo.vault;
        }

        (latestDirectionalFlowData, ) = initializeVaultFlowData(
            vaultAddresses,
            currentBlockNumber,
            order
        );

        bool safetyModeOff = true;
        for (uint256 i = 0; i < latestDirectionalFlowData.length; i++) {
            bool allowTransaction;
            bool isSafetyModeActivated;
            (
                latestDirectionalFlowData[i],
                allowTransaction,
                isSafetyModeActivated
            ) = updateVaultFlowSafety(
                latestDirectionalFlowData[i],
                order.vaultsWithAmount[i].amount,
                order.vaultsWithAmount[i].vaultInfo.persistedMetadata.shortFlowThreshold
            );

            if (isSafetyModeActivated) {
                safetyModeOff = false;
            }
            if (!allowTransaction) {
                return (Errors.VAULT_FLOW_TOO_HIGH, latestDirectionalFlowData, vaultAddresses);
            }
        }

        if (!safetyModeOff) {
            emit SafetyStatus(Errors.OPERATION_SUCCEEDS_BUT_SAFETY_MODE_ACTIVATED);
            return ("", latestDirectionalFlowData, vaultAddresses);
        }

        return ("", latestDirectionalFlowData, vaultAddresses);
    }

    /// @notice Checks whether a mint operation is safe
    /// @return empty string if it is safe, otherwise the reason why it is not safe
    function isMintSafe(DataTypes.Order memory order) external returns (string memory) {
        (string memory mintSafety, , ) = flowSafetyStateUpdater(order);
        return mintSafety;
    }

    //TODO: ensure only callable by motherboard
    /// @notice Checks whether a mint operation is safe
    /// This is only called when an actual mint is performed
    /// The implementation should store any relevant information for the mint
    /// @return empty string if it is safe, otherwise the reason why it is not safe
    function checkAndPersistMint(DataTypes.Order memory order) external returns (string memory) {
        (
            string memory mintSafety,
            DataTypes.DirectionalFlowData[] memory latestDirectionalFlowData,
            address[] memory vaultAddresses
        ) = flowSafetyStateUpdater(order);
        storeDirectionalFlowData(latestDirectionalFlowData, order, vaultAddresses);
        return mintSafety;
    }

    /// @notice Checks whether a redeem operation is safe
    /// @return empty string if it is safe, otherwise the reason why it is not safe
    function isRedeemSafe(DataTypes.Order memory order) external returns (string memory) {
        (string memory redeemSafety, , ) = flowSafetyStateUpdater(order);
        return redeemSafety;
    }

    //TODO: ensure only callable by motherboard
    /// @notice Checks whether a redeem operation is safe
    /// This is only called when an actual redeem is performed
    /// The implementation should store any relevant information for the redeem
    /// @return empty string if it is safe, otherwise the reason why it is not safe
    function checkAndPersistRedeem(DataTypes.Order memory order) external returns (string memory) {
        (
            string memory redeemSafety,
            DataTypes.DirectionalFlowData[] memory latestDirectionalFlowData,
            address[] memory vaultAddresses
        ) = flowSafetyStateUpdater(order);
        storeDirectionalFlowData(latestDirectionalFlowData, order, vaultAddresses);
        return redeemSafety;
    }
}
