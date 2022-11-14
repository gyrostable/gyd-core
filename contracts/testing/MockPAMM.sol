// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.


pragma solidity ^0.8.4;

import "../../interfaces/IPAMM.sol";

contract MockPAMM is IPAMM {
    /// @inheritdoc IPAMM
    function computeMintAmount(uint256 amount, uint256) external pure override returns (uint256) {
        return amount;
    }

    /// @inheritdoc IPAMM
    function mint(uint256 amount, uint256) external pure override returns (uint256) {
        return amount;
    }

    /// @inheritdoc IPAMM
    function computeRedeemAmount(uint256 amount, uint256) external pure override returns (uint256) {
        return amount;
    }

    /// @inheritdoc IPAMM
    function redeem(uint256 amount, uint256) external pure override returns (uint256) {
        return amount;
    }

    /// @notice Allows for the system parameters to be updated
    function setSystemParams(Params memory params) external pure {
        return;
    }
}
