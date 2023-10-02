// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

// NOTE: This is the same code as ILiquidityMining.sol in the governance repo.

interface ILiquidityMining {
    event Stake(address indexed account, uint256 amount);
    event Unstake(address indexed account, uint256 amount);
    event Claim(address indexed beneficiary, uint256 amount);

    event StartMining(uint256 amount, uint256 endTime);
    event StopMining();

    /// @notice claims rewards for caller
    function claimRewards() external returns (uint256);

    /// @notice returns the amount of claimable rewards by `beneficiary`
    function claimableRewards(
        address beneficiary
    ) external view returns (uint256);

    /// @notice the total amount of tokens staked in the contract
    function totalStaked() external view returns (uint256);

    /// @notice the amount of tokens staked by `account`
    function stakedBalanceOf(address account) external view returns (uint256);

    /// @notice returns the number of rewards token that will be given per second for the contract
    /// This emission will be given to all stakers in the contract proportionally to their stake
    function rewardsEmissionRate() external view returns (uint256);

    /// @notice time when rewards emission ends
    function rewardsEmissionEndTime() external view returns (uint256);

    /// @dev these functions will be called internally but can typically be called by anyone
    /// to update the internal tracking state of the contract
    function globalCheckpoint() external;

    function userCheckpoint(address account) external;

    /// @notice Deposit `amount` of the reward token from `rewardsFrom` and enable rewards until `endTime`. Typically governanceOnly. `amount` is spread evenly over the time period.
    function startMining(address rewardsFrom, uint256 amount, uint256 endTime) external;

    /// @notice Stop liquidity mining early and reimburse leftover rewards to the DAO treasury.
    /// This may also be needed after the mining period has ended when we had `totalStaked() == 0` for a while, where no rewards accrue.
    function stopMining() external;
}
