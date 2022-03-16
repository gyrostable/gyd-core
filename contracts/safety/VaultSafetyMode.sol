// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

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
import "../../libraries/EnumerableExtensions.sol";

contract VaultSafetyMode is ISafetyCheck, Governable {
    using FixedPoint for uint256;
    using StringExtensions for string;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableExtensions for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet internal whitelist;

    /// @notice Emmited when the motherboard is changed
    event MotherboardAddressChanged(address oldMotherboard, address newMotherboard);

    /// @notice Emitted when entering safety mode
    event SafetyStatus(string err);

    /// @notice Emitted when a whitelisted address protects a vault
    event OracleGuardianActivated(address vaultAddress, uint256 durationOfProtectionInBlocks);

    event AddedToWhitelist(address indexed account);
    event RemovedFromWhitelist(address indexed account);

    mapping(address => DataTypes.FlowData) public persistedFlowData;

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
            persistedFlowData[_vaultAddresses[i]].inFlow.shortFlow = 0;
            persistedFlowData[_vaultAddresses[i]].inFlow.remainingSafetyBlocks = 0;

            persistedFlowData[_vaultAddresses[i]].outFlow.shortFlow = 0;
            persistedFlowData[_vaultAddresses[i]].outFlow.remainingSafetyBlocks = 0;

            persistedFlowData[_vaultAddresses[i]].lastSeenBlock = block.number;
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
                persistedFlowData[vaultAddresses[i]].inFlow = directionalFlowData[i];
                if (order.vaultsWithAmount[i].amount > 0) {
                    persistedFlowData[vaultAddresses[i]].lastSeenBlock = currentBlockNumber;
                }
            }
        } else {
            for (uint256 i = 0; i < directionalFlowData.length; i++) {
                persistedFlowData[vaultAddresses[i]].outFlow = directionalFlowData[i];
                if (order.vaultsWithAmount[i].amount > 0) {
                    persistedFlowData[vaultAddresses[i]].lastSeenBlock = currentBlockNumber;
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
                directionalFlowData[i] = persistedFlowData[vaultAddresses[i]].inFlow;
                lastSeenBlock[i] = persistedFlowData[vaultAddresses[i]].lastSeenBlock;
            }
        } else {
            for (uint256 i = 0; i < vaultAddresses.length; i++) {
                directionalFlowData[i] = persistedFlowData[vaultAddresses[i]].outFlow;
                lastSeenBlock[i] = persistedFlowData[vaultAddresses[i]].lastSeenBlock;
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

    function getWhitelist() external view returns (address[] memory whitelistedAddresses) {
        for (uint256 i = 0; i < whitelist.length(); i++) {
            whitelistedAddresses[i] = whitelist.at(i);
        }
    }

    function addAddressToWhitelist(address _addressToAdd) external governanceOnly {
        whitelist.add(_addressToAdd);
        emit AddedToWhitelist(_addressToAdd);
    }

    function removeAddressFromWhitelist(address _addressToRemove) external governanceOnly {
        whitelist.remove(_addressToRemove);
        emit RemovedFromWhitelist(_addressToRemove);
    }

    modifier isWhitelisted(address _address) {
        require(whitelist.contains(_address), "Address not whitelisted");
        _;
    }

    function activateOracleGuardian(
        DataTypes.GuardedVaults memory vaultToProtect,
        uint256 blocksToActivate
    ) external isWhitelisted(msg.sender) {
        require(blocksToActivate <= safetyBlocksGuardian, Errors.ORACLE_GUARDIAN_TIME_LIMIT);

        if (
            vaultToProtect.direction == DataTypes.Direction.In ||
            vaultToProtect.direction == DataTypes.Direction.Both
        ) {
            persistedFlowData[vaultToProtect.vaultAddress]
                .inFlow
                .remainingSafetyBlocks = blocksToActivate;
            emit OracleGuardianActivated(vaultToProtect.vaultAddress, blocksToActivate);
        }
        if (
            vaultToProtect.direction == DataTypes.Direction.Out ||
            vaultToProtect.direction == DataTypes.Direction.Both
        ) {
            persistedFlowData[vaultToProtect.vaultAddress]
                .outFlow
                .remainingSafetyBlocks = blocksToActivate;
            emit OracleGuardianActivated(vaultToProtect.vaultAddress, blocksToActivate);
        }
    }
}
