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
        // SOMEDAY maybe we can save some bits, pack this to save a slot.
        uint256 lastUpdatedFullBurnId;
        uint256 adjustedAmount;
    }
    // owner -> Position
    mapping(address => Position) internal positions;

    // Full burn ID -> totalStakedIntegral at that point in time
    mapping(uint256 => uint256) internal fullBurnHistory;
    uint256 internal nextFullBurnId = 1; // 0 is invalid; we use this to detect unset data.

    uint256 public adjustmentFactor = 1e18;

    struct PendingWithdrawal {
        // SOMEDAY maybe we can save some bits, pack this to save a slot.
        uint256 createdFullBurnId;
        uint256 adjustedAmount;
        uint256 withdrawableAt; // timestamp
        address to;
    }
    mapping(uint256 => PendingWithdrawal) internal pendingWithdrawals;
    // address -> pending withdrawal ids. Mostly a convenience feature.
    mapping(address => EnumerableSet.UintSet) internal userPendingWithdrawalIds;
    uint256 internal nextWithdrawalId;
    uint256 public withdrawalWaitDuration;

    // We bound two variables by immutables to provide some certainty for fund providers vs governance actions.
    uint256 public immutable maxWithdrawalWaitDuration;
    uint256 public immutable maxTriggerCR;

    IGyroConfig public immutable gyroConfig;
    IGYDToken public immutable gydToken;

    event Deposit(address beneficiary, uint256 adjustedAmount, uint256 amount);
    event WithdrawalQueued(
        uint256 id,
        address to,
        uint256 withdrawalAt,
        uint256 adjustedAmount,
        uint256 amount
    );
    event WithdrawalCompleted(uint256 id, address to, uint256 adjustedAmount, uint256 amount);
    event RecoveryExecuted(uint256 tokensBurned, bool isFullBurn, uint256 newAdjustmentFactor);

    constructor(
        address _governor,
        address _gyroConfig,
        address _rewardToken,
        uint256 _withdrawalWaitDuration,
        uint256 _maxWithdrawalWaitDuration,
        uint256 _maxTriggerCR
    ) Governable(_governor) LiquidityMining(_rewardToken) {
        gyroConfig = IGyroConfig(_gyroConfig);
        gydToken = gyroConfig.getGYDToken();
        require(
            _withdrawalWaitDuration <= _maxWithdrawalWaitDuration,
            "invalid withdrawal wait duration"
        );
        withdrawalWaitDuration = _withdrawalWaitDuration;
        maxWithdrawalWaitDuration = _maxWithdrawalWaitDuration;
        maxTriggerCR = _maxTriggerCR;
    }

    function startMining(
        address rewardsFrom,
        uint256 amount,
        uint256 endTime
    ) external override governanceOnly {
        _startMining(rewardsFrom, amount, endTime);
    }

    function stopMining(address reimbursementTo) external override governanceOnly {
        _stopMining(reimbursementTo);
    }

    function setWithdrawalWaitDuration(uint256 _duration) external governanceOnly {
        require(_duration <= maxWithdrawalWaitDuration, "invalid withdrawal wait duration");
        withdrawalWaitDuration = _duration;
    }

    /// @dev Total amount available for burning. Includes amounts marked for withdrawal but not yet withdrawn.
    function totalUnderlying() public view returns (uint256) {
        return gydToken.balanceOf(address(this));
    }

    /// @notice Balance of given account that is available for withdrawal.
    function balanceOf(address account) public view returns (uint256) {
        return balanceAdjustedOf(account).mulDown(adjustmentFactor);
    }

    /// @notice Like balanceOf() but in adjusted amounts.
    function balanceAdjustedOf(address account) public view returns (uint256 adjustedAmount) {
        adjustedAmount = positions[account].lastUpdatedFullBurnId < nextFullBurnId
            ? 0
            : _perUserStaked[account];
    }

    /// @notice Total amount contributed of a given account, consisting of the amount available for withdrawal and the
    /// amount that has already been marked for withdrawal.
    function totalBalanceOf(address account) public view returns (uint256 amount) {
        // SOMEDAY Perhaps remove this actually; it's not clear people want to see it. If so, we can completely remove
        // Position.adjustedAmount. We don't use that anywhere else.
        return totalBalanceAdjustedOf(account).mulDown(adjustmentFactor);
    }

    /// @notice Like `totalBalanceOf()` but in adjusted amounts.
    function totalBalanceAdjustedOf(address account) public view returns (uint256 adjustedAmount) {
        Position memory position = positions[account];
        adjustedAmount = position.lastUpdatedFullBurnId < nextFullBurnId
            ? 0
            : position.adjustedAmount;
    }

    function adjustedAmountToAmount(uint256 adjustedAmount) external view returns (uint256 amount) {
        return adjustedAmount.mulDown(adjustmentFactor);
    }

    function amountToAdjustedAmount(uint256 amount) external view returns (uint256 adjustedAmount) {
        return amount.divDown(adjustmentFactor);
    }

    function deposit(uint256 amount) external {
        return depositFor(msg.sender, amount);
    }

    function depositFor(address beneficiary, uint256 amount) public {
        gydToken.safeTransferFrom(msg.sender, address(this), amount);

        uint256 adjustedAmount = amount.divDown(adjustmentFactor);
        _stake(beneficiary, adjustedAmount); // This also handles full burns and initializes new positions, which is important.
        positions[beneficiary].adjustedAmount += adjustedAmount;

        emit Deposit(beneficiary, adjustedAmount, amount);
    }

    function initiateWithdrawal(uint256 amount) external returns (uint256 withdrawalId) {
        return initiateWithdrawalAdjusted(amount.divDown(adjustmentFactor));
    }

    /// @notice Like initiateWithdrawal() but operates on adjusted amounts. Convenient to withdraw all funds
    /// via `initiateWithdrawalAdjusted(balanceAdjustedOf(account))` without worrying about rounding issues.
    function initiateWithdrawalAdjusted(uint256 adjustedAmount)
        public
        returns (uint256 withdrawalId)
    {
        // redundant with _unstake() but we want a better error message.
        require(adjustedAmount <= balanceOf(msg.sender), "not enough to withdraw");

        _unstake(msg.sender, adjustedAmount); // This also handles full burns, which is important below.

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

    function withdraw(uint256 withdrawalId) external returns (uint256 amount) {
        PendingWithdrawal memory pending = pendingWithdrawals[withdrawalId];
        require(pending.to == msg.sender, "matching withdrawal does not exist");
        require(pending.withdrawableAt <= block.timestamp, "not yet withdrawable");

        if (pending.createdFullBurnId < nextFullBurnId) {
            delete pendingWithdrawals[withdrawalId];
            userPendingWithdrawalIds[pending.to].remove(withdrawalId);
            emit WithdrawalCompleted(withdrawalId, pending.to, 0, 0);
            return 0;
        }

        positions[pending.to].adjustedAmount -= pending.adjustedAmount;

        amount = pending.adjustedAmount.mulDown(adjustmentFactor);
        gydToken.safeTransfer(pending.to, amount);

        delete pendingWithdrawals[withdrawalId];
        userPendingWithdrawalIds[pending.to].remove(withdrawalId);

        emit WithdrawalCompleted(withdrawalId, pending.to, pending.adjustedAmount, amount);
    }

    function listPendingWithdrawals(address _user)
        external
        view
        returns (PendingWithdrawal[] memory)
    {
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
    function userCheckpoint(address account) public override {
        globalCheckpoint();

        Position storage position = positions[account];
        uint256 lastUpdatedFullBurnId = position.lastUpdatedFullBurnId;

        uint256 perUserStaked = _perUserStaked[account];
        uint256 totalStakedIntegral;
        if (lastUpdatedFullBurnId == 0) {
            // Empty / new position. Initialize.
            totalStakedIntegral = _totalStakedIntegral;
            position.lastUpdatedFullBurnId = nextFullBurnId;
        } else if (lastUpdatedFullBurnId < nextFullBurnId) {
            // The user receives rewards for their staked (= not withdrawal-initiated) amount until the first burn after
            // the last userCheckpoint() and we update their position going forward.
            totalStakedIntegral = fullBurnHistory[lastUpdatedFullBurnId];

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

    function claimableRewards(address beneficiary) external view override returns (uint256) {
        uint256 lastUpdatedFullBurnId = positions[beneficiary].lastUpdatedFullBurnId;

        uint256 totalStakedIntegral;
        if (lastUpdatedFullBurnId > 0 && lastUpdatedFullBurnId < nextFullBurnId) {
            totalStakedIntegral = fullBurnHistory[lastUpdatedFullBurnId];
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

    function shouldRun() external view returns (bool) {
        return shouldRun(gyroConfig.getReserveManager().getReserveState());
    }

    /// @dev Whether or not the recovery module should run and would run next time it's called.
    function shouldRun(DataTypes.ReserveState memory reserveState) public view returns (bool) {
        if (totalUnderlying() == 0) {
            // *Not* a corner case! This happens after a full burn!
            return false;
        }
        uint256 currentCR = reserveState.totalUSDValue.divDown(gydToken.totalSupply());
        uint256 triggerCR = gyroConfig.getUint(ConfigKeys.GYD_RECOVERY_TRIGGER_CR);
        uint256 maxTriggerCR_ = maxTriggerCR;
        if (triggerCR > maxTriggerCR_) triggerCR = maxTriggerCR_;
        return currentCR < triggerCR;
    }

    function _checkAndRun(DataTypes.ReserveState memory reserveState) internal returns (bool) {
        if (!shouldRun(reserveState)) return false;

        // Compute amount to burn to reach target CR.
        uint256 targetCR = gyroConfig.getUint(ConfigKeys.GYD_RECOVERY_TARGET_CR);
        uint256 targetGYDSupply = reserveState.totalUSDValue.divDown(targetCR);
        uint256 currentGYDSupply = gydToken.totalSupply();

        if (targetGYDSupply >= currentGYDSupply) {
            // Sanity check. This can only happen if GYD_RECOVERY_TARGET_CR < GYD_RECOVERY_TRIGGER_CR, which is probably a buggy config.
            return false;
        }
        uint256 amountToBurn = currentGYDSupply - targetGYDSupply;

        return executeBurn(amountToBurn);
    }

    function checkAndRun(DataTypes.ReserveState memory reserveState) external returns (bool) {
        require(msg.sender == address(gyroConfig.getMotherboard()), "not authorized");
        return _checkAndRun(reserveState);
    }

    function checkAndRun() external returns (bool) {
        // Since _checkAndRun() may change the GYD supply, we need to call checkpoint() to correctly account for the GYD
        // supply until now (and also the reserve ratio). Motherboard does this itself before it calls
        // checkAndRun(ReserveState).
        // SOMEDAY gas optimization: Share reserveState between this function and checkpoint(); it's computed twice rn.
        gyroConfig.getReserveStewardshipIncentives().checkpoint();

        DataTypes.ReserveState memory reserveState = gyroConfig
            .getReserveManager()
            .getReserveState();
        return _checkAndRun(reserveState);
    }

    /// @dev Burn `amountToBurn` or the whole pool, whichever is smaller. Do proper accounting.
    function executeBurn(uint256 amountToBurn) internal returns (bool) {
        globalCheckpoint();

        uint256 _totalUnderlying = totalUnderlying();
        bool isFullBurn = amountToBurn >=
            _totalUnderlying.mulDown(FixedPoint.ONE - MAX_PARTIAL_BURN_FACTOR);

        if (isFullBurn) {
            amountToBurn = _totalUnderlying;
            fullBurnHistory[nextFullBurnId] = _totalStakedIntegral;
            ++nextFullBurnId;
            adjustmentFactor = FixedPoint.ONE;

            // The following makes totalStaked inconsistent with _perUserStaked but this is accounted for in userCheckpoint(), balanceAdjustedOf(), etc.
            totalStaked = 0;
        } else {
            uint256 nextAdjustmentFactor = adjustmentFactor
                .mulDown(_totalUnderlying - amountToBurn)
                .divDown(_totalUnderlying);
            if (nextAdjustmentFactor == 0) {
                // Handle a potential numerical error when many large partial burns occurred over time. We then prevent
                // the burn from running to make sure withdrawals don't lock up. This code should never run. Instead,
                // governance should monitor adjustmentFactor to notice this condition ahead of time, then ask
                // contributors to withdraw funds, and deploy a new instance of the contract.
                return false;
            }
            adjustmentFactor = nextAdjustmentFactor;
        }

        gydToken.burn(amountToBurn);
        emit RecoveryExecuted(amountToBurn, isFullBurn, adjustmentFactor);
        return true;
    }
}
