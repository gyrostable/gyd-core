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

    //TODO: does this need any sort of Access Control?
    mapping(address => DataTypes.FlowData) public flowSafetyDataStorage;

    uint256 public immutable safetyBlocksAutomatic;
    uint256 public immutable safetyBlocksGuardian;

    uint256 public constant THRESHOLD_BUFFER = 8e17;

    event SafetyModeActivated(bool);

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
    function storeFlowSafetyData(
        DataTypes.FlowData[] memory flowData,
        address[] memory vaultAddresses
    ) private {
        for (uint256 i = 0; i < flowData.length; i++) {
            flowSafetyDataStorage[vaultAddresses[i]] = flowData[i];
        }
    }

    //TODO: gas optimize this. The parameters for this contract could also potentially be packed here.
    function accessFlowSafetyData(address[] memory vaultAddresses)
        private
        view
        returns (DataTypes.FlowData[] memory flowData)
    {
        for (uint256 i = 0; i < vaultAddresses.length; i++) {
            flowData[i] = flowSafetyDataStorage[vaultAddresses[i]];
        }
    }

    function initializeVaultFlowData(
        address[] memory vaultAddresses,
        uint256 currentBlockNumber,
        Order memory order
    ) internal view returns (DataTypes.FlowData[] memory newData) {
        newData = accessFlowSafetyData(vaultAddresses);

        for (uint256 i = 0; i < newData.length; i++) {
            uint256 blocksElapsed = currentBlockNumber - newData[i].lastSeenBlock;

            newData[i].remainingSafetyBlocksIn = calculateRemainingBlocks(
                newData[i].remainingSafetyBlocksIn,
                blocksElapsed
            );

            newData[i].remainingSafetyBlocksOut = calculateRemainingBlocks(
                newData[i].remainingSafetyBlocksOut,
                blocksElapsed
            );

            newData[i].shortFlowIn = FlowSafety.updateFlow(
                newData[i].shortFlowIn,
                currentBlockNumber,
                newData[i].lastSeenBlock,
                order.vaultsWithAmount[i].vaultInfo.persistedMetadata.shortFlowMemory
            );

            newData[i].shortFlowOut = FlowSafety.updateFlow(
                newData[i].shortFlowOut,
                currentBlockNumber,
                newData[i].lastSeenBlock,
                order.vaultsWithAmount[i].vaultInfo.persistedMetadata.shortFlowMemory
            );

            newData[i].lastSeenBlock = currentBlockNumber;
        }

        return newData;
    }

    // TODO: emit events when a safety mode is activated
    function updateVaultFlowSafety(
        DataTypes.FlowData memory flowData,
        uint256 proposedFlowChange,
        bool mint,
        uint256 shortFlowThreshold
    )
        private
        view
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
            if (newInFlow > shortFlowThreshold) {
                allowTransaction = false;
                flowData.remainingSafetyBlocksIn = safetyBlocksAutomatic;
            } else if (newInFlow > THRESHOLD_BUFFER * shortFlowThreshold) {
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
            if (newOutFlow > shortFlowThreshold) {
                allowTransaction = false;
                flowData.remainingSafetyBlocksOut = safetyBlocksAutomatic;
            } else if (newOutFlow > THRESHOLD_BUFFER * shortFlowThreshold) {
                flowData.remainingSafetyBlocksOut = safetyBlocksAutomatic;
                flowData.shortFlowOut += newOutFlow;
                isSafetyModeActivated = true;
            } else {
                flowData.shortFlowOut += newOutFlow;
            }
        }

        return (flowData, allowTransaction, isSafetyModeActivated);
    }

    //TODO: make a whitelist of addresses that can call this and make this list settable by governance
    function activateOracleGuardian(
        DataTypes.GuardedVaults[] memory vaultsToProtect,
        uint256 blocksToActivate
    ) external {
        DataTypes.FlowData[] memory flowSafetyDataUpdate;
        require(blocksToActivate <= safetyBlocksGuardian, Errors.ORACLE_GUARDIAN_TIME_LIMIT);

        address[] memory vaultAddresses;
        for (uint256 i = 0; i < vaultsToProtect.length; i++) {
            vaultAddresses[i] = vaultsToProtect[i].vaultAddress;
        }

        for (uint256 i = 0; i < vaultsToProtect.length; i++) {
            if (vaultsToProtect[i].direction == 0 || vaultsToProtect[i].direction == 3) {
                flowSafetyDataUpdate[i].remainingSafetyBlocksIn = blocksToActivate;
            }
            if (vaultsToProtect[i].direction == 1 || vaultsToProtect[i].direction == 3) {
                flowSafetyDataUpdate[i].remainingSafetyBlocksOut = blocksToActivate;
            }
        }

        storeFlowSafetyData(flowSafetyDataUpdate, vaultAddresses);
    }

    function flowSafetyEngine(Order memory order)
        internal
        view
        returns (
            string memory,
            DataTypes.FlowData[] memory latestFlowData,
            address[] memory vaultAddresses
        )
    {
        uint256 currentBlockNumber = block.number;

        for (uint256 i = 0; i < order.vaultsWithAmount.length; i++) {
            vaultAddresses[i] = order.vaultsWithAmount[i].vaultInfo.vault;
        }

        latestFlowData = initializeVaultFlowData(vaultAddresses, currentBlockNumber, order);

        bool safetyModeOff = true;
        for (uint256 i = 0; i < latestFlowData.length; i++) {
            bool allowTransaction;
            bool isSafetyModeActivated;
            (latestFlowData[i], allowTransaction, isSafetyModeActivated) = updateVaultFlowSafety(
                latestFlowData[i],
                order.vaultsWithAmount[i].amount,
                order.mint,
                order.vaultsWithAmount[i].vaultInfo.persistedMetadata.shortFlowThreshold
            );
            if (isSafetyModeActivated) {
                safetyModeOff = false;
            }
            if (!allowTransaction) {
                return (Errors.VAULT_FLOW_TOO_HIGH, latestFlowData, vaultAddresses);
            }
        }

        if (!safetyModeOff) {
            return (
                Errors.OPERATION_SUCCEEDS_BUT_SAFETY_MODE_ACTIVATED,
                latestFlowData,
                vaultAddresses
            );
        }

        return ("", latestFlowData, vaultAddresses);
    }

    /// @notice Checks whether a mint operation is safe
    /// @return empty string if it is safe, otherwise the reason why it is not safe
    function isMintSafe(Order memory order) external view returns (string memory) {
        (string memory mintSafety, , ) = flowSafetyEngine(order);
        return mintSafety;
    }

    //TODO: ensure only callable by motherboard
    /// @notice Checks whether a mint operation is safe
    /// This is only called when an actual mint is performed
    /// The implementation should store any relevant information for the mint
    /// @return empty string if it is safe, otherwise the reason why it is not safe
    function checkAndPersistMint(Order memory order) external returns (string memory) {
        (
            string memory mintSafety,
            DataTypes.FlowData[] memory latestFlowData,
            address[] memory vaultAddresses
        ) = flowSafetyEngine(order);
        storeFlowSafetyData(latestFlowData, vaultAddresses);
        return mintSafety;
    }

    /// @notice Checks whether a redeem operation is safe
    /// @return empty string if it is safe, otherwise the reason why it is not safe
    function isRedeemSafe(Order memory order) external view returns (string memory) {
        (string memory redeemSafety, , ) = flowSafetyEngine(order);
        return redeemSafety;
    }

    //TODO: ensure only callable by motherboard
    /// @notice Checks whether a redeem operation is safe
    /// This is only called when an actual redeem is performed
    /// The implementation should store any relevant information for the redeem
    /// @return empty string if it is safe, otherwise the reason why it is not safe
    function checkAndPersistRedeem(Order memory order) external returns (string memory) {
        (
            string memory redeemSafety,
            DataTypes.FlowData[] memory latestFlowData,
            address[] memory vaultAddresses
        ) = flowSafetyEngine(order);
        storeFlowSafetyData(latestFlowData, vaultAddresses);
        return redeemSafety;
    }
}
