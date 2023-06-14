// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "./DataTypes.sol";
import "./FixedPoint.sol";

library VaultMetadataExtension {
    using FixedPoint for uint256;

    function scheduleWeight(DataTypes.PersistedVaultMetadata memory metadata)
        internal
        view
        returns (uint256)
    {
        uint256 timeSinceCalibration = block.timestamp - metadata.timeOfCalibration;
        if (timeSinceCalibration >= metadata.weightTransitionDuration)
            return metadata.weightAtCalibration;

        uint256 multiplier = timeSinceCalibration.divDown(
            uint256(metadata.weightTransitionDuration)
        );
        uint256 weightDifference = metadata.weightAtCalibration.absSub(
            metadata.weightAtPreviousCalibration
        );
        uint256 weightDelta = weightDifference.mulDown(multiplier);

        if (metadata.weightAtCalibration > metadata.weightAtPreviousCalibration) {
            return metadata.weightAtPreviousCalibration + weightDelta;
        } else {
            return metadata.weightAtPreviousCalibration - weightDelta;
        }
    }
}
