// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../../interfaces/IAssetRegistry.sol";
import "../../interfaces/IGyroConfig.sol";

import "../../libraries/Errors.sol";
import "../../libraries/DataTypes.sol";
import "../../libraries/ConfigKeys.sol";
import "../../libraries/EnumerableExtensions.sol";

import "../auth/GovernableUpgradeable.sol";

contract AssetRegistry is IAssetRegistry, GovernableUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableExtensions for EnumerableSet.Bytes32Set;
    using EnumerableExtensions for EnumerableSet.AddressSet;

    /// @notice a stablecoin should be equal to 1 USD
    uint256 public constant STABLECOIN_IDEAL_PRICE = 1e18;

    mapping(string => address) internal assets;
    mapping(address => DataTypes.Range) internal assetRanges;

    IGyroConfig public immutable gyroConfig;

    EnumerableSet.Bytes32Set internal assetNames;
    EnumerableSet.AddressSet internal assetAddresses;
    EnumerableSet.AddressSet internal stableAssetAddresses;

    constructor(IGyroConfig _gyroConfig) {
        gyroConfig = _gyroConfig;
    }

    /// @inheritdoc IAssetRegistry
    function isAssetNameRegistered(string calldata assetName)
        external
        view
        override
        returns (bool)
    {
        return assets[assetName] != address(0);
    }

    /// @inheritdoc IAssetRegistry
    function isAssetAddressRegistered(address assetAddress) external view override returns (bool) {
        return assetAddresses.contains(assetAddress);
    }

    /// @inheritdoc IAssetRegistry
    function isAssetStable(address assetAddress) external view returns (bool) {
        return stableAssetAddresses.contains(assetAddress);
    }

    /// @inheritdoc IAssetRegistry
    function getAssetRange(address asset) external view override returns (DataTypes.Range memory) {
        DataTypes.Range memory range = assetRanges[asset];
        require(range.ceiling > 0, Errors.ASSET_NOT_SUPPORTED);
        return range;
    }

    /// @inheritdoc IAssetRegistry
    function getRegisteredAssetNames() external view returns (bytes32[] memory) {
        return assetNames.toArray();
    }

    /// @inheritdoc IAssetRegistry
    function getRegisteredAssetAddresses() external view returns (address[] memory) {
        return assetAddresses.toArray();
    }

    /// @inheritdoc IAssetRegistry
    function getStableAssets() external view returns (address[] memory) {
        return stableAssetAddresses.toArray();
    }

    /// @inheritdoc IAssetRegistry
    function getAssetAddress(string calldata assetName) external view returns (address) {
        address assetAddress = assets[assetName];
        require(assetAddress != address(0), Errors.ASSET_NOT_SUPPORTED);
        return assetAddress;
    }

    /// @inheritdoc IAssetRegistry
    function setAssetAddress(string memory assetName, address assetAddress)
        external
        governanceOnly
    {
        require(bytes(assetName).length < 32, Errors.INVALID_ARGUMENT);
        require(assetAddress != address(0), Errors.INVALID_ARGUMENT);

        address previousAddress = assets[assetName];
        require(previousAddress != assetAddress, Errors.INVALID_ARGUMENT);
        assets[assetName] = assetAddress;

        assetNames.add(bytes32(bytes(assetName)));
        assetAddresses.add(assetAddress);

        emit AssetAddressUpdated(assetName, previousAddress, assetAddress);
    }

    /// @inheritdoc IAssetRegistry
    function addStableAsset(address asset) external governanceOnly {
        require(assetAddresses.contains(asset), Errors.ASSET_NOT_SUPPORTED);
        stableAssetAddresses.add(asset);
        emit StableAssetAdded(asset);
    }

    /// @inheritdoc IAssetRegistry
    function setAssetRange(address asset, DataTypes.Range memory range) external governanceOnly {
        require(assetAddresses.contains(asset), Errors.ASSET_NOT_SUPPORTED);
        require(range.floor < range.ceiling, Errors.INVALID_ARGUMENT);
        assetRanges[asset] = range;
        emit AssetRangeUpdated(asset, range);
    }

    /// @inheritdoc IAssetRegistry
    function removeStableAsset(address asset) external governanceOnly {
        require(stableAssetAddresses.contains(asset), Errors.ASSET_NOT_SUPPORTED);
        stableAssetAddresses.remove(asset);
        emit StableAssetRemoved(asset);
    }

    /// @inheritdoc IAssetRegistry
    function removeAsset(string memory assetName) external governanceOnly {
        address assetAddress = assets[assetName];
        require(assetAddress != address(0), Errors.ASSET_NOT_SUPPORTED);
        delete assets[assetName];
        assetNames.remove(bytes32(bytes(assetName)));
        assetAddresses.remove(assetAddress);
        stableAssetAddresses.remove(assetAddress);
    }
}
