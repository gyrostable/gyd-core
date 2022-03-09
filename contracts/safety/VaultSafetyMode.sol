// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./../auth/Governable.sol";
import "../../libraries/DataTypes.sol";
import "../../interfaces/IReserveManager.sol";
import "../../interfaces/IAssetRegistry.sol";
import "../../interfaces/IGyroVault.sol";
import "../../interfaces/balancer/IVault.sol";
import "../../libraries/Errors.sol";
import "../../interfaces/ISafetyCheck.sol";
import "../../interfaces/IVaultRegistry.sol";
import "../../libraries/FixedPoint.sol";
import "../../libraries/Flow.sol";
import "../../libraries/StringExtensions.sol";

contract VaultSafetyMode is ISafetyCheck, Governable {
    using FixedPoint for uint256;
    using StringExtensions for string;

    /// @notice Emmited when the motherboard is changed
    event MotherboardAddressChanged(address oldMotherboard, address newMotherboard);

    /// @notice Emitted when entering safety mode
    event SafetyStatus(string err);

    mapping(address => DataTypes.FlowData) public flowDataBidirectionalStored;
    mapping(address => bool) public whitelist;

    uint256 public immutable safetyBlocksAutomatic;
    uint256 public immutable safetyBlocksGuardian;

    uint256 public constant THRESHOLD_BUFFER = 8e17;

    address public motherboardAddress;

    constructor(
        uint256 _safetyBlocksAutomatic,
        uint256 _safetyBlocksGuardian,
        address _motherboardAddress,
        address[] memory _vaultAddresses
    ) {
        safetyBlocksAutomatic = _safetyBlocksAutomatic;
        safetyBlocksGuardian = _safetyBlocksGuardian;
        motherboardAddress = _motherboardAddress;
        deploymentInitialization(_vaultAddresses);
    }

    function deploymentInitialization(address[] memory _vaultAddresses) internal {
        for (uint256 i = 0; i < _vaultAddresses.length; i++) {
            flowDataBidirectionalStored[_vaultAddresses[i]].inFlow.shortFlow = 0;
            flowDataBidirectionalStored[_vaultAddresses[i]].inFlow.remainingSafetyBlocks = 0;

            flowDataBidirectionalStored[_vaultAddresses[i]].outFlow.shortFlow = 0;
            flowDataBidirectionalStored[_vaultAddresses[i]].outFlow.remainingSafetyBlocks = 0;

            flowDataBidirectionalStored[_vaultAddresses[i]].lastSeenBlock = block.number;
        }
    }

    function setMotherboardAddress(address _address) external governanceOnly {
        address oldMotherboardAddress = motherboardAddress;
        motherboardAddress = _address;
        emit MotherboardAddressChanged(oldMotherboardAddress, _address);
    }

    modifier motherboardOnly() {
        require(msg.sender == motherboardAddress, Errors.CALLER_NOT_MOTHERBOARD);
        _;
    }

    function _calculateRemainingBlocks(uint256 lastRemainingBlocks, uint256 blocksElapsed)
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
    function _storeDirectionalFlowData(
        DataTypes.DirectionalFlowData[] memory directionalFlowData,
        DataTypes.Order memory order,
        address[] memory vaultAddresses,
        uint256 currentBlockNumber
    ) internal {
        require(directionalFlowData.length == vaultAddresses.length, Errors.NOT_ENOUGH_FLOW_DATA);
        if (order.mint) {
            for (uint256 i = 0; i < directionalFlowData.length; i++) {
                flowDataBidirectionalStored[vaultAddresses[i]].inFlow = directionalFlowData[i];
                if (order.vaultsWithAmount[i].amount > 0) {
                    flowDataBidirectionalStored[vaultAddresses[i]]
                        .lastSeenBlock = currentBlockNumber;
                }
            }
        } else {
            for (uint256 i = 0; i < directionalFlowData.length; i++) {
                flowDataBidirectionalStored[vaultAddresses[i]].outFlow = directionalFlowData[i];
                if (order.vaultsWithAmount[i].amount > 0) {
                    flowDataBidirectionalStored[vaultAddresses[i]]
                        .lastSeenBlock = currentBlockNumber;
                }
            }
        }
    }

    //TODO: gas optimize this. The parameters for this contract could also potentially be packed here.
    function _accessDirectionalFlowData(
        address[] memory vaultAddresses,
        DataTypes.Order memory order
    )
        internal
        view
        returns (
            DataTypes.DirectionalFlowData[] memory directionalFlowData,
            uint256[] memory lastSeenBlock
        )
    {
        directionalFlowData = new DataTypes.DirectionalFlowData[](vaultAddresses.length);
        lastSeenBlock = new uint256[](vaultAddresses.length);

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

    function _fetchLatestDirectionalFlowData(
        address[] memory vaultAddresses,
        uint256 currentBlockNumber,
        DataTypes.Order memory order
    ) internal view returns (DataTypes.DirectionalFlowData[] memory) {
        (
            DataTypes.DirectionalFlowData[] memory directionalFlowData,
            uint256[] memory lastSeenBlock
        ) = _accessDirectionalFlowData(vaultAddresses, order);

        for (uint256 i = 0; i < directionalFlowData.length; i++) {
            uint256 blocksElapsed = currentBlockNumber - lastSeenBlock[i];

            directionalFlowData[i].remainingSafetyBlocks = _calculateRemainingBlocks(
                directionalFlowData[i].remainingSafetyBlocks,
                blocksElapsed
            );

            directionalFlowData[i].shortFlow = Flow.updateFlow(
                directionalFlowData[i].shortFlow,
                currentBlockNumber,
                lastSeenBlock[i],
                order.vaultsWithAmount[i].vaultInfo.persistedMetadata.shortFlowMemory
            );
        }
        return directionalFlowData;
    }

    function _updateVaultFlowSafety(
        DataTypes.DirectionalFlowData memory directionalFlowData,
        uint256 proposedFlowChange,
        uint256 shortFlowThreshold
    )
        internal
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

    function _flowSafetyStateUpdater(DataTypes.Order memory order)
        internal
        view
        returns (
            string memory,
            DataTypes.DirectionalFlowData[] memory latestDirectionalFlowData,
            address[] memory vaultAddresses,
            uint256 currentBlockNumber
        )
    {
        currentBlockNumber = block.number;

        vaultAddresses = new address[](order.vaultsWithAmount.length);
        latestDirectionalFlowData = new DataTypes.DirectionalFlowData[](
            order.vaultsWithAmount.length
        );

        for (uint256 i = 0; i < order.vaultsWithAmount.length; i++) {
            vaultAddresses[i] = order.vaultsWithAmount[i].vaultInfo.vault;
        }

        latestDirectionalFlowData = _fetchLatestDirectionalFlowData(
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
            ) = _updateVaultFlowSafety(
                latestDirectionalFlowData[i],
                order.vaultsWithAmount[i].amount,
                order.vaultsWithAmount[i].vaultInfo.persistedMetadata.shortFlowThreshold
            );

            if (isSafetyModeActivated) {
                safetyModeOff = false;
            }
            if (!allowTransaction) {
                return (
                    Errors.VAULT_FLOW_TOO_HIGH,
                    latestDirectionalFlowData,
                    vaultAddresses,
                    currentBlockNumber
                );
            }
        }

        if (!safetyModeOff) {
            return (
                Errors.OPERATION_SUCCEEDS_BUT_SAFETY_MODE_ACTIVATED,
                latestDirectionalFlowData,
                vaultAddresses,
                currentBlockNumber
            );
        }

        return ("", latestDirectionalFlowData, vaultAddresses, currentBlockNumber);
    }

    /// @notice Checks whether a mint operation is safe
    /// @return empty string if it is safe, otherwise the reason why it is not safe
    function isMintSafe(DataTypes.Order memory order) external view returns (string memory) {
        (string memory mintSafety, , , ) = _flowSafetyStateUpdater(order);
        return mintSafety;
    }

    /// @notice Checks whether a mint operation is safe
    /// This is only called when an actual mint is performed
    /// The implementation should store any relevant information for the mint
    /// @return empty string if it is safe, otherwise the reason why it is not safe
    function checkAndPersistMint(DataTypes.Order memory order)
        external
        motherboardOnly
        returns (string memory)
    {
        (
            string memory err,
            DataTypes.DirectionalFlowData[] memory latestDirectionalFlowData,
            address[] memory vaultAddresses,
            uint256 currentBlockNumber
        ) = _flowSafetyStateUpdater(order);

        if (bytes(err).length > 0) {
            if (err.compareStrings(Errors.OPERATION_SUCCEEDS_BUT_SAFETY_MODE_ACTIVATED)) {
                emit SafetyStatus(err);
            } else {
                revert(Errors.NOT_SAFE_TO_MINT);
            }
        }

        _storeDirectionalFlowData(
            latestDirectionalFlowData,
            order,
            vaultAddresses,
            currentBlockNumber
        );
        return err;
    }

    /// @notice Checks whether a redeem operation is safe
    /// @return empty string if it is safe, otherwise the reason why it is not safe
    function isRedeemSafe(DataTypes.Order memory order) external view returns (string memory) {
        (string memory redeemSafety, , , ) = _flowSafetyStateUpdater(order);
        return redeemSafety;
    }

    /// @notice Checks whether a redeem operation is safe
    /// This is only called when an actual redeem is performed
    /// The implementation should store any relevant information for the redeem
    /// @return empty string if it is safe, otherwise the reason why it is not safe
    function checkAndPersistRedeem(DataTypes.Order memory order)
        external
        motherboardOnly
        returns (string memory)
    {
        (
            string memory err,
            DataTypes.DirectionalFlowData[] memory latestDirectionalFlowData,
            address[] memory vaultAddresses,
            uint256 currentBlockNumber
        ) = _flowSafetyStateUpdater(order);

        if (bytes(err).length > 0) {
            if (err.compareStrings(Errors.OPERATION_SUCCEEDS_BUT_SAFETY_MODE_ACTIVATED)) {
                emit SafetyStatus(err);
            } else {
                revert(Errors.NOT_SAFE_TO_REDEEM);
            }
        }

        _storeDirectionalFlowData(
            latestDirectionalFlowData,
            order,
            vaultAddresses,
            currentBlockNumber
        );
        return err;
    }

    function addAddressToWhitelist(address _address) external governanceOnly {
        whitelist[_address] = true;
    }

    function isOnWhitelist(address _address) public view returns (bool) {
        return whitelist[_address];
    }

    modifier isWhitelisted(address _address) {
        require(whitelist[_address], "Address not whitelisted");
        _;
    }

    function activateOracleGuardian(
        DataTypes.GuardedVaults[] memory vaultsToProtect,
        uint256 blocksToActivate
    ) external isWhitelisted(msg.sender) {
        require(blocksToActivate <= safetyBlocksGuardian, Errors.ORACLE_GUARDIAN_TIME_LIMIT);

        for (uint256 i = 0; i < vaultsToProtect.length; i++) {
            if (
                vaultsToProtect[i].direction == DataTypes.Direction.In ||
                vaultsToProtect[i].direction == DataTypes.Direction.Both
            ) {
                flowDataBidirectionalStored[vaultsToProtect[i].vaultAddress]
                    .inFlow
                    .remainingSafetyBlocks = blocksToActivate;
            }
            if (
                vaultsToProtect[i].direction == DataTypes.Direction.Out ||
                vaultsToProtect[i].direction == DataTypes.Direction.Both
            ) {
                flowDataBidirectionalStored[vaultsToProtect[i].vaultAddress]
                    .outFlow
                    .remainingSafetyBlocks = blocksToActivate;
            }
        }
    }
}
