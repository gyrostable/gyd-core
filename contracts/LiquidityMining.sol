// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../interfaces/ILiquidityMining.sol";
import "../libraries/FixedPoint.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract LiquidityMining is ILiquidityMining {
    using FixedPoint for uint256;
    using SafeERC20 for IERC20;

    uint256 public override totalStaked;

    uint256 internal _totalStakedIntegral;
    uint256 internal _lastCheckpointTime;
    /// @dev This contract only tracks these, we don't use it; but it may be convenient for inheriting contracts.
    uint256 internal _totalUnclaimedRewards;
    mapping(address => uint256) internal _perUserStakedIntegral;
    mapping(address => uint256) internal _perUserShare;
    mapping(address => uint256) internal _perUserStaked;

    uint256 internal _rewardsEmissionRate;
    uint256 public override rewardsEmissionEndTime;

    IERC20 public immutable rewardToken;

    constructor(address _rewardToken) {
        _lastCheckpointTime = block.timestamp;
        rewardToken = IERC20(_rewardToken);
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

    /// @dev Helper function for the inheriting contract. Authorization should be performed by the inheriting contract.
    function _startMining(
        address rewardsFrom,
        uint256 amount,
        uint256 endTime
    ) internal {
        globalCheckpoint();
        rewardToken.safeTransferFrom(rewardsFrom, address(this), amount);
        _rewardsEmissionRate = amount / (endTime - block.timestamp);
        rewardsEmissionEndTime = endTime;
        emit StartMining(amount, endTime);
    }

    /// @dev same as `_startLiquidityMining` but for stopping.
    function _stopMining(address reimbursementTo) internal {
        globalCheckpoint();
        uint256 reimbursementAmount = rewardToken.balanceOf(address(this)) - _totalUnclaimedRewards;
        rewardToken.safeTransfer(reimbursementTo, reimbursementAmount);
        rewardsEmissionEndTime = 0;
        emit StopMining();
    }

    function _mintRewards(address beneficiary, uint256 amount) internal returns (uint256) {
        rewardToken.safeTransfer(beneficiary, amount);
        return amount;
    }

    function rewardsEmissionRate() public view override returns (uint256) {
        return block.timestamp <= rewardsEmissionEndTime ? _rewardsEmissionRate : 0;
    }

    /// @dev These functions would typically be overloaded by the calling contract to perform its own authorization and
    /// then call the underscore versions.
    function startMining(address rewardsFrom, uint256 amount, uint256 endTime) external virtual;
    function stopMining(address reimbursementTo) external virtual;
}
