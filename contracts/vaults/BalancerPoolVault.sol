// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "../../interfaces/balancer/IVault.sol";

import "./BaseVault.sol";

contract BalancerPoolVault is BaseVault {
    IVault public immutable balancerVault;

    /// @notice Balancer pool ID
    bytes32 public poolId;

    /// @inheritdoc IGyroVault
    Vaults.Type public override vaultType;

    constructor(address _gyroConfig, IVault _balancerVault) BaseVault(_gyroConfig) {
        balancerVault = _balancerVault;
    }

    function initialize(
        bytes32 _poolId,
        address governor,
        string memory name,
        string memory symbol,
        Vaults.Type _vaultType
    ) external virtual initializer {
        __BaseVault_initialize(_getPoolAddress(_poolId), governor, name, symbol);
        poolId = _poolId;
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
