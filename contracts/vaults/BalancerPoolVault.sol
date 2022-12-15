// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "../../interfaces/balancer/IVault.sol";

import "./BaseVault.sol";

contract BalancerPoolVault is BaseVault {
    /// @notice Balancer pool ID
    bytes32 public immutable poolId;

    IVault public immutable balancerVault;

    /// @inheritdoc IGyroVault
    Vaults.Type public immutable override vaultType;

    constructor(
        address _governor,
        Vaults.Type _vaultType,
        bytes32 _poolId,
        IVault _balancerVault,
        string memory name,
        string memory symbol
    ) BaseVault(_governor, _getPoolAddress(_poolId), name, symbol) {
        poolId = _poolId;
        balancerVault = _balancerVault;
        vaultType = _vaultType;
    }

    /// @inheritdoc IGyroVault
    function getTokens() external view override returns (IERC20[] memory) {
        (IERC20[] memory tokens, , ) = balancerVault.getPoolTokens(poolId);
        return tokens;
    }

    function _getPoolAddress(bytes32 _poolId) internal pure returns (address) {
        // 12 byte logical shift left to remove the nonce and specialization setting. We don't need to mask,
        // since the logical shift already sets the upper bits to zero.
        return address(uint160(uint256(_poolId) >> (12 * 8)));
    }
}
