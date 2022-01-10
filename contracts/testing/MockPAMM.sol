// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

import "../../interfaces/IPAMM.sol";

contract MockPAMM is IPAMM {
    /// @inheritdoc IPAMM
    function computeMintAmount(uint256 amount) external pure override returns (uint256) {
        return amount;
    }

    /// @inheritdoc IPAMM
    function mint(uint256 amount) external pure override returns (uint256) {
        return amount;
    }

    /// @inheritdoc IPAMM
    function computeRedeemAmount(uint256 amount) external pure override returns (uint256) {
        return amount;
    }

    /// @inheritdoc IPAMM
    function redeem(uint256 amount) external pure override returns (uint256) {
        return amount;
    }
}
