// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./auth/Governable.sol";
import "../libraries/DataTypes.sol";
import "../libraries/FlowSafety.sol";
import "../interfaces/IVaultManager.sol";
import "../interfaces/IAssetRegistry.sol";
import "../interfaces/IGyroVault.sol";
import "../interfaces/balancer/IVault.sol";
import "../libraries/Errors.sol";
import "../interfaces/ISafetyCheck.sol";
import "../interfaces/IVaultRegistry.sol";

contract VaultSafetyMode is ISafetyCheck, Governable {
    using FixedPoint for uint256;

    mapping(address => DataTypes.FlowData) public flowSafetyData;

    DataTypes.SafetyTimeParams public safetyTimeParams;

    uint256 constant thresholdBuffer = 8e17;

    event SafetyModeActivated(bool);

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

    function updateVaultFlows(address[] memory vaultAddresses, uint256 currentBlockNumber)
        internal
        view
        returns (DataTypes.FlowData[] memory memoryFlowSafetyData)
    {
        memoryFlowSafetyData = accessFlowSafetyData(vaultAddresses);

        for (uint256 i = 0; i < memoryFlowSafetyData.length; i++) {
            uint256 blocksElapsed = currentBlockNumber - memoryFlowSafetyData[i].lastSeenBlock;

            memoryFlowSafetyData[i].remainingSafetyBlocksIn = calculateRemainingBlocks(
                memoryFlowSafetyData[i].remainingSafetyBlocksIn,
                blocksElapsed
            );

            memoryFlowSafetyData[i].remainingSafetyBlocksOut = calculateRemainingBlocks(
                memoryFlowSafetyData[i].remainingSafetyBlocksOut,
                blocksElapsed
            );

            memoryFlowSafetyData[i].shortFlowIn = FlowSafety.updateFlow(
                memoryFlowSafetyData[i].shortFlowIn,
                currentBlockNumber,
                memoryFlowSafetyData[i].lastSeenBlock,
                memoryFlowSafetyData[i].shortFlowMemory
            );

            memoryFlowSafetyData[i].shortFlowOut = FlowSafety.updateFlow(
                memoryFlowSafetyData[i].shortFlowOut,
                currentBlockNumber,
                memoryFlowSafetyData[i].lastSeenBlock,
                memoryFlowSafetyData[i].shortFlowMemory
            );

            memoryFlowSafetyData[i].lastSeenBlock = currentBlockNumber;
        }

        return memoryFlowSafetyData;
    }

    // TODO: emit events when a safety mode is activated
    function checkVaultFlow(
        DataTypes.FlowData memory flowData,
        uint256 proposedFlowChange,
        bool mint,
        uint256 safetyBlocksAutomatic
    )
        private
        pure
        returns (
            DataTypes.FlowData memory,
            bool,
            bool
        )
    {
        bool allowTransaction = true;
        bool isSafetyModeActivated = false;
        if (mint) {
            if (flowData.remainingSafetyBlocksIn > 0) {
                return (flowData, false, true);
            }
            uint256 newInFlow = flowData.shortFlowIn + proposedFlowChange;
            if (newInFlow > flowData.shortFlowThreshold) {
                allowTransaction = false;
                flowData.remainingSafetyBlocksIn = safetyBlocksAutomatic;
            } else if (newInFlow > thresholdBuffer * flowData.shortFlowThreshold) {
                flowData.remainingSafetyBlocksIn = safetyBlocksAutomatic;
                flowData.shortFlowIn += newInFlow;
                isSafetyModeActivated = true;
            } else {
                flowData.shortFlowIn += newInFlow;
            }
        } else {
            if (flowData.remainingSafetyBlocksOut > 0) {
                return (flowData, false, true);
            }
            uint256 newOutFlow = flowData.shortFlowOut + proposedFlowChange;
            if (newOutFlow > flowData.shortFlowThreshold) {
                allowTransaction = false;
                flowData.remainingSafetyBlocksOut = safetyBlocksAutomatic;
            } else if (newOutFlow > thresholdBuffer * flowData.shortFlowThreshold) {
                flowData.remainingSafetyBlocksOut = safetyBlocksAutomatic;
                flowData.shortFlowOut += newOutFlow;
                isSafetyModeActivated = true;
            } else {
                flowData.shortFlowOut += newOutFlow;
            }
        }

        return (flowData, allowTransaction, isSafetyModeActivated);
    }

    /// @notice Checks whether a mint operation is safe
    /// This is only called when an actual mint is performed
    /// The implementation should store any relevant information for the mint
    /// @return empty string if it is safe, otherwise the reason why it is not safe
    function checkAndPersistMint(Order memory order) public returns (string memory) {
        uint256 currentBlockNumber = block.number;

        address[] memory vaultAddresses;
        for (uint256 i = 0; i < order.vaultsWithAmount.length; i++) {
            vaultAddresses[i] = order.vaultsWithAmount[i].vaultInfo.vault;
        }

        DataTypes.FlowData[] memory latestFlowData = updateVaultFlows(
            vaultAddresses,
            currentBlockNumber
        );

        bool safetyModeOff = true;
        for (uint256 i = 0; i < latestFlowData.length; i++) {
            bool allowTransaction;
            bool isSafetyModeActivated;
            (latestFlowData[i], allowTransaction, isSafetyModeActivated) = checkVaultFlow(
                latestFlowData[i],
                order.vaultsWithAmount[i].amount,
                order.mint,
                safetyTimeParams.safetyBlocksAutomatic
            );

            if (isSafetyModeActivated) {
                safetyModeOff = false;
            }
            if (!allowTransaction) {
                return Errors.VAULT_FLOW_TOO_HIGH;
            }
        }

        if (!safetyModeOff) {
            emit SafetyModeActivated(safetyModeOff);
        }

        storeFlowSafetyData(latestFlowData, vaultAddresses);

        return "";
    }

    //TODO: gas optimize this
    function storeFlowSafetyData(
        DataTypes.FlowData[] memory flowData,
        address[] memory vaultAddresses
    ) private {
        for (uint256 i = 0; i < flowData.length; i++) {
            flowSafetyData[vaultAddresses[i]] = flowData[i];
        }
    }

    //TODO: gas optimize this. The parameters for this contract could also potentially be packed here.
    function accessFlowSafetyData(address[] memory vaultAddresses)
        private
        view
        returns (DataTypes.FlowData[] memory flowData)
    {
        for (uint256 i = 0; i < vaultAddresses.length; i++) {
            flowData[i] = flowSafetyData[vaultAddresses[i]];
        }
    }

    //TODO: make a whitelist of addresses that can call this and make this list settable by governance
    function activateOracleGuardian(DataTypes.GuardedVaults[] memory vaultsToProtect) external {
        DataTypes.FlowData[] memory flowSafetyDataUpdate;
        DataTypes.SafetyTimeParams memory memorySafetyTimeParams = safetyTimeParams;

        address[] memory vaultAddresses;
        for (uint256 i = 0; i < vaultsToProtect.length; i++) {
            vaultAddresses[i] = vaultsToProtect[i].vaultAddress;
        }

        for (uint256 i = 0; i < vaultsToProtect.length; i++) {
            if (vaultsToProtect[i].direction == 0 || vaultsToProtect[i].direction == 3) {
                flowSafetyDataUpdate[i].remainingSafetyBlocksIn = memorySafetyTimeParams
                    .safetyBlocksGuardian;
            }
            if (vaultsToProtect[i].direction == 1 || vaultsToProtect[i].direction == 3) {
                flowSafetyDataUpdate[i].remainingSafetyBlocksOut = memorySafetyTimeParams
                    .safetyBlocksGuardian;
            }
        }

        storeFlowSafetyData(flowSafetyDataUpdate, vaultAddresses);
    }

    /// @notice Checks whether a mint operation is safe
    /// @return empty string if it is safe, otherwise the reason why it is not safe
    function isMintSafe(Order memory order) public view returns (string memory) {
        uint256 currentBlockNumber = block.number;

        address[] memory vaultAddresses;
        for (uint256 i = 0; i < order.vaultsWithAmount.length; i++) {
            vaultAddresses[i] = order.vaultsWithAmount[i].vaultInfo.vault;
        }

        DataTypes.FlowData[] memory latestFlowData = updateVaultFlows(
            vaultAddresses,
            currentBlockNumber
        );

        bool safetyModeOff = true;
        for (uint256 i = 0; i < latestFlowData.length; i++) {
            bool allowTransaction;
            bool isSafetyModeActivated;
            (latestFlowData[i], allowTransaction, isSafetyModeActivated) = checkVaultFlow(
                latestFlowData[i],
                order.vaultsWithAmount[i].amount,
                order.mint,
                safetyTimeParams.safetyBlocksAutomatic
            );
            if (isSafetyModeActivated) {
                safetyModeOff = false;
            }
            if (!allowTransaction) {
                return Errors.VAULT_FLOW_TOO_HIGH;
            }
        }

        if (!safetyModeOff) {
            return Errors.OPERATION_SUCCEEDS_BUT_SAFETY_MODE_ACTIVATED;
        }

        return "";
    }

    /// @notice Checks whether a redeem operation is safe
    /// @return empty string if it is safe, otherwise the reason why it is not safe
    function isRedeemSafe(Order memory order) external view returns (string memory) {
        return isMintSafe(order);
    }

    /// @notice Checks whether a redeem operation is safe
    /// This is only called when an actual redeem is performed
    /// The implementation should store any relevant information for the redeem
    /// @return empty string if it is safe, otherwise the reason why it is not safe
    function checkAndPersistRedeem(Order memory order) external returns (string memory) {
        return checkAndPersistMint(order);
    }
}
