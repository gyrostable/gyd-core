// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./../auth/Governable.sol";
import "../../libraries/DataTypes.sol";
import "../../interfaces/IGyroConfig.sol";
import "../../interfaces/IAssetRegistry.sol";
import "../../interfaces/IGyroVault.sol";
import "../../interfaces/balancer/IVault.sol";
import "../../libraries/Errors.sol";
import "../../interfaces/ISafetyCheck.sol";
import "../../interfaces/IVaultRegistry.sol";
import "../../libraries/FixedPoint.sol";
import "../../libraries/Flow.sol";
import "../../libraries/Errors.sol";
import "../../libraries/StringExtensions.sol";
import "../../libraries/ConfigHelpers.sol";

contract VaultSafetyMode is ISafetyCheck, Governable {
    using FixedPoint for uint256;
    using StringExtensions for string;
    using EnumerableSet for EnumerableSet.AddressSet;
    using ConfigHelpers for IGyroConfig;

    EnumerableSet.AddressSet internal whitelist;

    /// @notice Emitted when entering safety mode
    event SafetyStatus(string err);

    /// @notice Emitted when a whitelisted address protects a vault
    event OracleGuardianActivated(
        address vaultAddress,
        uint256 durationOfProtectionInBlocks,
        bool inFlows
    );

    event AddedToWhitelist(address indexed account);
    event RemovedFromWhitelist(address indexed account);

    struct FlowResult {
        uint256 newFlow;
        bool safetyModeActivated;
    }

    mapping(address => DataTypes.FlowData) public persistedFlowData;

    IGyroConfig public immutable gyroConfig;

    uint256 public constant THRESHOLD_BUFFER = 8e17;

    constructor(address governor, address _gyroConfig) Governable(governor) {
        gyroConfig = IGyroConfig(_gyroConfig);
    }

    modifier rootSafetyCheckOnly() {
        require(msg.sender == address(gyroConfig.getRootSafetyCheck()), Errors.NOT_AUTHORIZED);
        _;
    }

    /// @notice Checks whether a mint operation is safe
    /// @return err empty string if it is safe, otherwise the reason why it is not safe
    function isMintSafe(DataTypes.Order memory order) external view returns (string memory err) {
        if (order.mint) {
            (err, ) = _checkFlows(order);
        } else {
            err = Errors.INVALID_ARGUMENT;
        }
    }

    /// @inheritdoc ISafetyCheck
    function checkAndPersistMint(DataTypes.Order memory order) external rootSafetyCheckOnly {
        require(order.mint, Errors.INVALID_ARGUMENT);
        (string memory err, FlowResult[] memory result) = _checkFlows(order);

        if (bytes(err).length > 0) {
            if (err.compareStrings(Errors.OPERATION_SUCCEEDS_BUT_SAFETY_MODE_ACTIVATED)) {
                emit SafetyStatus(err);
            } else {
                revert(err);
            }
        }

        _updateFlows(order, result);
    }

    /// @notice Checks whether a redeem operation is safe
    /// @return err empty string if it is safe, otherwise the reason why it is not safe
    function isRedeemSafe(DataTypes.Order memory order) external view returns (string memory err) {
        if (!order.mint) {
            (err, ) = _checkFlows(order);
        } else {
            err = Errors.INVALID_ARGUMENT;
        }
    }

    /// @notice Checks whether a redeem operation is safe
    /// This is only called when an actual redeem is performed
    /// The implementation should store any relevant information for the redeem
    function checkAndPersistRedeem(DataTypes.Order memory order) external rootSafetyCheckOnly {
        require(!order.mint, Errors.INVALID_ARGUMENT);
        (string memory err, FlowResult[] memory result) = _checkFlows(order);

        if (bytes(err).length > 0) {
            if (err.compareStrings(Errors.OPERATION_SUCCEEDS_BUT_SAFETY_MODE_ACTIVATED)) {
                emit SafetyStatus(err);
            } else {
                revert(err);
            }
        }

        _updateFlows(order, result);
    }

    function getWhitelist() external view returns (address[] memory) {
        return whitelist.values();
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
        require(whitelist.contains(_address), Errors.NOT_AUTHORIZED);
        _;
    }

    function activateOracleGuardian(DataTypes.GuardedVaults memory vaultToProtect, uint256 blocks)
        external
        isWhitelisted(msg.sender)
    {
        _activateOracleGuardian(vaultToProtect, blocks);
    }

    function pauseProtocol(bool depositsOnly) external isWhitelisted(msg.sender) {
        IVaultRegistry vaultRegistry = gyroConfig.getVaultRegistry();
        address[] memory vaults = vaultRegistry.listVaults();
        DataTypes.Direction direction = depositsOnly
            ? DataTypes.Direction.In
            : DataTypes.Direction.Both;
        uint256 blocksToActivate = gyroConfig.getUint(ConfigKeys.SAFETY_BLOCKS_GUARDIAN);
        for (uint256 i = 0; i < vaults.length; i++) {
            DataTypes.GuardedVaults memory vaultToProtect = DataTypes.GuardedVaults(
                vaults[i],
                direction
            );
            _activateOracleGuardian(vaultToProtect, blocksToActivate);
        }
    }

    function _checkFlows(DataTypes.Order memory order)
        internal
        view
        returns (string memory err, FlowResult[] memory result)
    {
        result = new FlowResult[](order.vaultsWithAmount.length);

        for (uint256 i; i < order.vaultsWithAmount.length; i++) {
            uint256 amount = order.vaultsWithAmount[i].amount;
            DataTypes.VaultInfo memory vault = order.vaultsWithAmount[i].vaultInfo;
            DataTypes.FlowData storage flowData = persistedFlowData[vault.vault];
            DataTypes.DirectionalFlowData memory directionalData;
            directionalData = order.mint ? flowData.inFlow : flowData.outFlow;

            if (amount > 0 && block.number <= directionalData.lastSafetyBlock) {
                err = Errors.SAFETY_MODE_ACTIVATED;
                break;
            }

            uint256 shortFlowThreshold = vault.persistedMetadata.shortFlowThreshold;
            uint256 newFlow = amount +
                Flow.updateFlow(
                    directionalData.shortFlow,
                    block.number,
                    directionalData.lastSeenBlock,
                    vault.persistedMetadata.shortFlowMemory
                );

            if (amount > 0 && newFlow > shortFlowThreshold) {
                err = Errors.VAULT_FLOW_TOO_HIGH;
                break;
            }

            bool activateSafetyMode = newFlow > THRESHOLD_BUFFER.mulDown(shortFlowThreshold);
            if (activateSafetyMode) {
                err = Errors.OPERATION_SUCCEEDS_BUT_SAFETY_MODE_ACTIVATED;
            }

            result[i] = FlowResult(newFlow, activateSafetyMode);
        }
    }

    function _updateFlows(DataTypes.Order memory order, FlowResult[] memory result) internal {
        for (uint256 i; i < order.vaultsWithAmount.length; i++) {
            DataTypes.VaultInfo memory vault = order.vaultsWithAmount[i].vaultInfo;
            DataTypes.FlowData storage flowData = persistedFlowData[vault.vault];
            DataTypes.DirectionalFlowData storage directionalData;
            if (order.mint) {
                directionalData = flowData.inFlow;
            } else {
                directionalData = flowData.outFlow;
            }
            directionalData.lastSeenBlock = uint64(block.number);
            directionalData.shortFlow = uint128(result[i].newFlow);
            if (result[i].safetyModeActivated) {
                directionalData.lastSafetyBlock = uint64(
                    block.number + gyroConfig.getUint(ConfigKeys.SAFETY_BLOCKS_AUTOMATIC)
                );
            }
        }
    }

    function _activateOracleGuardian(DataTypes.GuardedVaults memory vaultToProtect, uint256 blocks)
        internal
    {
        require(
            blocks <= gyroConfig.getUint(ConfigKeys.SAFETY_BLOCKS_GUARDIAN),
            Errors.ORACLE_GUARDIAN_TIME_LIMIT
        );

        uint64 targetBlock = uint64(block.number + blocks);
        if (
            vaultToProtect.direction == DataTypes.Direction.In ||
            vaultToProtect.direction == DataTypes.Direction.Both
        ) {
            persistedFlowData[vaultToProtect.vaultAddress].inFlow.lastSafetyBlock = targetBlock;
            emit OracleGuardianActivated(vaultToProtect.vaultAddress, blocks, true);
        }
        if (
            vaultToProtect.direction == DataTypes.Direction.Out ||
            vaultToProtect.direction == DataTypes.Direction.Both
        ) {
            persistedFlowData[vaultToProtect.vaultAddress].outFlow.lastSafetyBlock = targetBlock;
            emit OracleGuardianActivated(vaultToProtect.vaultAddress, blocks, false);
        }
    }
}
