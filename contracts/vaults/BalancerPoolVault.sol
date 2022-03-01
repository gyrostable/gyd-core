// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../../interfaces/balancer/IVault.sol";

import "./BaseVault.sol";

contract BalancerPoolVault is BaseVault {
    /// @notice Balancer pool ID
    bytes32 public immutable poolId;

    IVault public immutable balancerVault;

    constructor(
        bytes32 _poolId,
        IVault _balancerVault,
        string memory name,
        string memory symbol
    ) BaseVault(_getPoolAddress(_poolId), name, symbol) {
        poolId = _poolId;
        balancerVault = _balancerVault;
    }

    /// @inheritdoc IGyroVault
    function getTokens() external view override returns (IERC20[] memory) {
        (IERC20[] memory tokens, , ) = balancerVault.getPoolTokens(poolId);
        return tokens;
    }

    /// @inheritdoc IGyroVault
    function vaultType() external pure override returns (VaultType) {
        return VaultType.BALANCER;
    }

    function _getPoolAddress(bytes32 _poolId) internal pure returns (address) {
        // 12 byte logical shift left to remove the nonce and specialization setting. We don't need to mask,
        // since the logical shift already sets the upper bits to zero.
        return address(uint160(uint256(_poolId) >> (12 * 8)));
    }
}
