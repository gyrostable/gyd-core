// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../interfaces/ILiquidityMining.sol";
import "../libraries/FixedPoint.sol";

abstract contract LiquidityMining is ILiquidityMining {
    using FixedPoint for uint256;

    uint256 public override totalStaked;

    uint256 internal _totalStakedIntegral;
    uint256 internal _lastCheckpointTime;
    /// @dev This contract only tracks these, we don't use it; but it may be convenient for inheriting contracts.
    uint256 internal _totalUnclaimedRewards;
    mapping(address => uint256) internal _perUserStakedIntegral;
    mapping(address => uint256) internal _perUserShare;
    mapping(address => uint256) internal _perUserStaked;

    constructor() {
        _lastCheckpointTime = block.timestamp;
    }

    function claimRewards() external returns (uint256) {
        userCheckpoint(msg.sender);
        uint256 amount = _perUserShare[msg.sender];
        if (amount == 0) return 0;
        delete _perUserShare[msg.sender];
        emit Claim(msg.sender, amount);
        _totalUnclaimedRewards -= amount;
        return _mintRewards(msg.sender, amount);
    }

    function claimableRewards(address beneficiary) external view virtual returns (uint256) {
        uint256 totalStakedIntegral = _totalStakedIntegral;
        if (totalStaked > 0) {
            totalStakedIntegral += (rewardsEmissionRate() * (block.timestamp - _lastCheckpointTime))
                .divDown(totalStaked);
        }

        return
            _perUserShare[beneficiary] +
            stakedBalanceOf(beneficiary).mulDown(
                totalStakedIntegral - _perUserStakedIntegral[beneficiary]
            );
    }

    function stakedBalanceOf(address account) public view returns (uint256) {
        return _perUserStaked[account];
    }

    function globalCheckpoint() public {
        uint256 elapsedTime = block.timestamp - _lastCheckpointTime;
        uint256 totalStaked_ = totalStaked;
        if (totalStaked_ > 0) {
            uint256 newRewards = rewardsEmissionRate() * elapsedTime;
            _totalStakedIntegral += newRewards.divDown(totalStaked_);
            _totalUnclaimedRewards += newRewards;
        }
        _lastCheckpointTime = block.timestamp;
    }

    function userCheckpoint(address account) public virtual {
        globalCheckpoint();
        uint256 totalStakedIntegral = _totalStakedIntegral;
        _perUserShare[account] += stakedBalanceOf(account).mulDown(
            totalStakedIntegral - _perUserStakedIntegral[account]
        );
        _perUserStakedIntegral[account] = totalStakedIntegral;
    }

    /// @dev this is a helper function to be used by the inheriting contract
    /// this does not perform any checks on the amount that `account` may or not have deposited
    /// and should be used with caution. All checks should be performed in the inheriting contract
    function _stake(address account, uint256 amount) internal {
        userCheckpoint(account);
        totalStaked += amount;
        _perUserStaked[account] += amount;
        emit Stake(account, amount);
    }

    /// @dev same as `_stake` but for unstaking
    function _unstake(address account, uint256 amount) internal {
        userCheckpoint(account);
        _perUserStaked[account] -= amount;
        totalStaked -= amount;
        emit Unstake(account, amount);
    }

    function rewardsEmissionRate() public view virtual returns (uint256);

    function _mintRewards(address beneficiary, uint256 amount) internal virtual returns (uint256);
}
