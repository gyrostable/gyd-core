pragma solidity ^0.8.0;

import "./auth/Governable.sol";
import "../interfaces/IGYDToken.sol";
import "../libraries/DataTypes.sol";
import "../libraries/FixedPoint.sol";
import "../interfaces/IGyroConfig.sol";
import "../libraries/ConfigKeys.sol";
import "../libraries/ConfigHelpers.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./LiquidityMining.sol";

import "../interfaces/IGydRecovery.sol";

contract GydRecovery is IGydRecovery, Governable, LiquidityMining {
    using FixedPoint for uint256;
    using ConfigHelpers for IGyroConfig;
    using SafeERC20 for IGYDToken;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    /* We account for burn actions (= when the mechanism is triggered) in two ways:
    - For partial burns, where less than the whole underlying supply is burnt, we store the percentage that has been burned in a cumulative adjustment factor. We can convert from and to "adjusted" amounts by multiplying/dividing by the adjustment factor. The "staked amounts" for liquidity mining are in units of *adjusted amounts*.
    - For full burns, where the whole supply is burnt, the conversion is not 1:1. Instead, we store a counter to distinguish whether a full burn has happened since the last update, and we also store some history.
    Adjusted amounts are only meaningful when the last full-burn-id is stored as well. All this is important to correctly perform accounting for withdrawals and for rewards.
    */

    /// @dev Max burn factor. If less than this share would be left over after burning, we do a full burn instead. This is to avoid numerical instability in the adjustment factor.
    uint256 internal constant MAX_PARTIAL_BURN_FACTOR = 0.01e18;

    /** @dev Full (marked for withdrawal and not) amount for a given address. We store the adjusted amount *not* marked for
     * withdrawal in _perUserStaked from LiquidityMining. We account for the fact that _perUserStaked can become outdated
     * in userCheckpoint() and in the related view methods.
     */
    struct Position {
        uint256 lastUpdatedFullBurnId;
        // TODO the following var is currently write-only. Remove unless we want to provide an (optional) view method to read this.
        uint256 adjustedAmount;
    }
    // owner -> Position
    mapping(address => Position) internal positions;

    struct FullBurnInfo {
        uint256 totalStakedIntegral;
    }
    // Full burn ID -> Data at that point in time
    mapping (uint256 => FullBurnInfo) internal fullBurnHistory;
    uint256 nextFullBurnId = 1;  // 0 is invalid; we use this to detect unset data.

    uint256 public adjustmentFactor = 1e18;

    struct PendingWithdrawal {
        uint256 createdFullBurnId;
        uint256 adjustedAmount;
        uint256 withdrawableAt;  // timestamp
        address to;
    }
    mapping (uint256 => PendingWithdrawal) internal pendingWithdrawals;
    // address -> pending withdrawal ids. Mostly a convenience feature.
    mapping(address => EnumerableSet.UintSet) internal userPendingWithdrawalIds;
    uint256 internal nextWithdrawalId;
    uint256 public withdrawalWaitDuration;

    uint256 internal _rewardsEmissionRate;
    uint256 public rewardsEmissionEndTime;

    IGyroConfig public immutable gyroConfig;
    IGYDToken public immutable gydToken;
    IERC20 public immutable rewardToken;

    event Deposit(address beneficiary, uint256 adjustedAmount, uint256 amount);
    event WithdrawalQueued(uint256 id, address to, uint256 withdrawalAt, uint256 adjustedAmount, uint256 amount);
    event WithdrawalCompleted(uint256 id, address to, uint256 adjustedAmount, uint256 amount);
    event RecoveryExecuted(uint256 tokensBurned, bool isFullBurn, uint256 newAdjustmentFactor);

    constructor(
        address _governor,
        address _gyroConfig,
        address _rewardToken,
        uint256 _withdrawalWaitDuration
    ) Governable(_governor)
    {
        gyroConfig = IGyroConfig(_gyroConfig);
        gydToken = gyroConfig.getGYDToken();
        rewardToken = IERC20(_rewardToken);
        withdrawalWaitDuration = _withdrawalWaitDuration;
    }

    function setWithdrawalWaitDuration(uint256 _duration) external governanceOnly {
        withdrawalWaitDuration = _duration;
    }

    /// @dev Total amount available for burning. Includes amounts marked for withdrawal but not yet withdrawn.
    function totalUnderlying() public view returns(uint256)
    {
        return gydToken.balanceOf(address(this));
    }

    /// @notice Balance of given account that is available for withdrawal.
    function balanceOf(address account) public view returns(uint256)
    {
        return balanceAdjustedOf(account).mulDown(adjustmentFactor);
    }

    /// @notice Like balanceOf() but in adjusted amounts.
    function balanceAdjustedOf(address account) public view returns (uint256 adjustedAmount)
    {
        adjustedAmount = positions[account].lastUpdatedFullBurnId < nextFullBurnId ? 0 : _perUserStaked[account];
    }

    function adjustedAmountToAmount(uint256 adjustedAmount) external view returns (uint256 amount)
    {
        return adjustedAmount.mulDown(adjustmentFactor);
    }

    function amountToAdjustedAmount(uint256 amount) external view returns (uint256 adjustedAmount)
    {
        return amount.divDown(adjustmentFactor);
    }

    function deposit(uint256 amount) external
    {
        return depositFor(msg.sender, amount);
    }

    function depositFor(address beneficiary, uint256 amount) public
    {
        gydToken.safeTransferFrom(msg.sender, address(this), amount);

        uint256 adjustedAmount = amount.divDown(adjustmentFactor);
        _stake(beneficiary, adjustedAmount);  // This also handles full burns, which is important for the next line.
        positions[beneficiary].adjustedAmount += adjustedAmount;

        emit Deposit(beneficiary, adjustedAmount, amount);
    }

    function initiateWithdrawal(uint256 amount) external returns (uint256 withdrawalId)
    {
        return initiateWithdrawalAdjusted(amount.divDown(adjustmentFactor));
    }

    /// @notice Like initiateWithdrawal() but operates on adjusted amounts. Convenient to withdraw all funds
    /// via `initiateWithdrawalAdjusted(balanceAdjustedOf(account))` without worrying about rounding issues.
    function initiateWithdrawalAdjusted(uint256 adjustedAmount) public returns (uint256 withdrawalId)
    {
        // redundant with _unstake() but we want a better error message.
        require(adjustedAmount <= balanceOf(msg.sender), "not enough to withdraw");

        _unstake(msg.sender, adjustedAmount);  // This also handles full burns, which is important below.

        withdrawalId = nextWithdrawalId;
        ++nextWithdrawalId;
        PendingWithdrawal memory withdrawal = PendingWithdrawal({
            createdFullBurnId: nextFullBurnId,
            adjustedAmount: adjustedAmount,
            withdrawableAt: block.timestamp + withdrawalWaitDuration,
            to: msg.sender
        });
        pendingWithdrawals[withdrawalId] = withdrawal;
        userPendingWithdrawalIds[withdrawal.to].add(withdrawalId);

        emit WithdrawalQueued(
            withdrawalId,
            withdrawal.to,
            withdrawal.withdrawableAt,
            adjustedAmount,
            adjustedAmount.mulDown(adjustmentFactor)
        );
    }

    function withdraw(uint256 withdrawalId) external returns (uint256 amount)
    {
        PendingWithdrawal memory pending = pendingWithdrawals[withdrawalId];
        require(
            pending.to == msg.sender,
            "matching withdrawal does not exist");
        require(
            pending.withdrawableAt <= block.timestamp,
            "not yet withdrawable"
        );

        if (pending.createdFullBurnId < nextFullBurnId) {
            delete pendingWithdrawals[withdrawalId];
            userPendingWithdrawalIds[pending.to].remove(withdrawalId);
            return 0;
        }

        positions[pending.to].adjustedAmount -= pending.adjustedAmount;

        amount = pending.adjustedAmount.mulDown(adjustmentFactor);
        gydToken.safeTransfer(pending.to, amount);

        delete pendingWithdrawals[withdrawalId];
        userPendingWithdrawalIds[pending.to].remove(withdrawalId);

        emit WithdrawalCompleted(withdrawalId, pending.to, adjustedAmount, amount);
    }

    function listPendingWithdrawals(
        address _user
    ) external view returns (PendingWithdrawal[] memory) {
        EnumerableSet.UintSet storage ids = userPendingWithdrawalIds[_user];
        PendingWithdrawal[] memory pending = new PendingWithdrawal[](ids.length());
        for (uint256 i = 0; i < ids.length(); i++) {
            pending[i] = pendingWithdrawals[ids.at(i)];
        }
        return pending;
    }

    /// @dev Update rewards accounting for user (see LiquidityMining.userCheckpoint()) and also update their
    /// position data in case of a full burn. It may look a bit ugly that these two things are mixed here but it's
    /// important to update them at the same time.
    function userCheckpoint(address account) public override
    {
        globalCheckpoint();

        Position storage position = positions[account];
        uint256 lastUpdatedFullBurnId = position.lastUpdatedFullBurnId;

        uint256 perUserStaked = _perUserStaked[account];
        uint256 totalStakedIntegral;
        if (lastUpdatedFullBurnId > 0 && lastUpdatedFullBurnId < nextFullBurnId) {
            // The user receives rewards for their staked (= not withdrawal-initiated) amount until the first burn after
            // the last userCheckpoint() and we update their position going forward.
            totalStakedIntegral = fullBurnHistory[lastUpdatedFullBurnId].totalStakedIntegral;

            position.adjustedAmount = 0;
            position.lastUpdatedFullBurnId = nextFullBurnId;
            delete _perUserStaked[account];
        } else {
            // No full burn since last userCheckpoint(). The user receives rewards until now.
            totalStakedIntegral = _totalStakedIntegral;
        }

        _perUserShare[account] += perUserStaked.mulDown(
            totalStakedIntegral - _perUserStakedIntegral[account]
        );
        _perUserStakedIntegral[account] = totalStakedIntegral;
    }

    function claimableRewards(address beneficiary) external view override returns (uint256)
    {
        uint256 lastUpdatedFullBurnId = positions[beneficiary].lastUpdatedFullBurnId;

        uint256 totalStakedIntegral;
        if (lastUpdatedFullBurnId > 0 && lastUpdatedFullBurnId < nextFullBurnId) {
            totalStakedIntegral = fullBurnHistory[lastUpdatedFullBurnId].totalStakedIntegral;
        } else {
            totalStakedIntegral = _totalStakedIntegral;
            if (totalStaked > 0) {
                totalStakedIntegral += (rewardsEmissionRate() *
                    (block.timestamp - _lastCheckpointTime)).divDown(totalStaked);
            }
        }

        return
            _perUserShare[beneficiary] +
            _perUserStaked[beneficiary].mulDown(
                totalStakedIntegral - _perUserStakedIntegral[beneficiary]
            );
    }

    function startLiquidityMining(address rewardsFrom, uint256 amount, uint256 endTime) external governanceOnly
    {
        globalCheckpoint();
        rewardToken.safeTransferFrom(rewardsFrom, address(this), amount);
        _rewardsEmissionRate = amount / (endTime - block.timestamp);
        rewardsEmissionEndTime = endTime;
    }

    /// @dev To stop liquidity mining early and/or have the amount reimbursed when liquidity mining was paused when the pool was empty for a while.
    function stopLiquidityMining(address reimbursementTo) external governanceOnly
    {
        globalCheckpoint();
        uint256 reimbursementAmount = rewardToken.balanceOf(address(this)) - _totalUnclaimedRewards;
        rewardToken.safeTransfer(reimbursementTo, reimbursementAmount);
        rewardsEmissionEndTime = 0;
    }

    function rewardsEmissionRate() public view override returns (uint256)
    {
        return block.timestamp <= rewardsEmissionEndTime ? _rewardsEmissionRate : 0;
    }

    function _mintRewards(address beneficiary, uint256 amount) internal override returns (uint256)
    {
        rewardToken.safeTransfer(beneficiary, amount);
        return amount;
    }

    /// @dev Whether or not the recovery module should run and would run next time it's called.
    function shouldRun(DataTypes.ReserveState memory reserveState) public view returns (bool)
    {
        if (totalUnderlying() == 0) {
            // *Not* a corner case! This happens after a full burn!
            return false;
        }
        uint256 currentCR = reserveState.totalUSDValue.divDown(gydToken.totalSupply());
        uint256 triggerCR = gyroConfig.getUint(ConfigKeys.GYD_RECOVERY_TRIGGER_CR);
        return currentCR < triggerCR;
    }

    /** @dev Check if the recovery module should run; do it if needed. Can be called by anyone.
     * @return has run? */
    function checkAndRun(DataTypes.ReserveState memory reserveState) public returns (bool)
    {
        if (!shouldRun(reserveState))
            return false;

        // Compute amount to burn to reach target CR.
        uint256 targetCR = gyroConfig.getUint(ConfigKeys.GYD_RECOVERY_TARGET_CR);
        uint256 targetGYDSupply = reserveState.totalUSDValue.divDown(targetCR);
        uint256 currentGYDSupply = gydToken.totalSupply();

        if (targetGYDSupply >= currentGYDSupply) {
            // Sanity check. This can only happen if GYD_RECOVERY_TARGET_CR < GYD_RECOVERY_TRIGGER_CR, which is probably a buggy config.
            return false;
        }
        uint256 amountToBurn = currentGYDSupply - targetGYDSupply;

        executeBurn(amountToBurn);
        return true;
    }

    function checkAndRun() external returns (bool)
    {
        DataTypes.ReserveState memory reserveState = gyroConfig
            .getReserveManager()
            .getReserveState();
        return checkAndRun(reserveState);
    }

    /// @dev Burn `amountToBurn` or the whole pool, whichever is smaller. Do proper accounting.
    function executeBurn(uint256 amountToBurn) internal
    {
        globalCheckpoint();

        uint256 _totalUnderlying = totalUnderlying();
        bool isFullBurn = amountToBurn >= _totalUnderlying.mulDown(FixedPoint.ONE - MAX_PARTIAL_BURN_FACTOR);

        if (isFullBurn) {
            amountToBurn = _totalUnderlying;
            fullBurnHistory[nextFullBurnId] = FullBurnInfo({
                totalStakedIntegral: _totalStakedIntegral
            });
            ++nextFullBurnId;
            adjustmentFactor = FixedPoint.ONE;

            // The following makes totalStaked inconsistent with _perUserStaked but this is accounted for in userCheckpoint(), balanceAdjustedOf(), etc.
            totalStaked = 0;
        } else {
            adjustmentFactor = adjustmentFactor.mulDown(_totalUnderlying - amountToBurn).divDown(_totalUnderlying);
            // NB In extreme cases, when many large partial burns occurred, this may make adjustmentFactor = 0 due to numerical
            // error. In this case, no further deposits or withdrawals are possible. This situation is hard to avoid while
            // keeping the contract's accounting right. Governance should monitor adjustmentFactor to notice this condition
            // ahead of time, then ask contributors to withdraw funds, and deploy a new instance of the contract.
            // TODO ^ To be discussed.
        }

        gydToken.burn(amountToBurn);
        emit RecoveryExecuted(amountToBurn, isFullBurn, adjustmentFactor);
    }
}
