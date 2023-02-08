pragma solidity ^0.8.0;

import "./auth/Governable.sol";
import "../interfaces/IGYDToken.sol";
import "../libraries/DataTypes.sol";
import "../libraries/FixedPoint.sol";
import "../interfaces/IGyroConfig.sol";
import "../libraries/ConfigKeys.sol";
import "../libraries/ConfigHelpers.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// TODO (Daniel) not Governable b/c there's no governance routines built in. Just double checking, is this ok?
contract GydRecovery {
    // TODO liquidity mining infrastructure
    // TODO lockup infrastructure

    using FixedPoint for uint256;
    using ConfigHelpers for IGyroConfig;
    using SafeERC20 for IGYDToken;

    struct Position {
        address owner;
        uint64 depositedBlock;  // for rewards only
        uint256 adjustedAmount;
    }
    // Mapping from position IDs to position data
    mapping (uint256 => Position) private positions;
    uint256 lastPositionId = 0;  // stores the *most recently used* ID. 0 is invalid.

    /* This factor tracks the burnt amounts in a gas-efficient way. adjustmentFactor is the product of (1 -
       pool shares burnt) across all burn actions since the beginning of time. It converts
       Position.adjustedAmount to actual GYD amounts, and back.
       This works *unless* the whole pool was burnt at some point (where the factor would be 0 and
       we can't go the other way by division). Therefore, we also store the time where that happened. This relies on
       position IDs increasing with each deposit operation.
    */
    // TODO review error accumulation / rounding direction for this. Could store adjustmentFactor in higher precision if needed.
    uint256 adjustmentFactor = 1e18;
    uint64 lastFullBurnPositionId = 0;

    event GydRecoveryRun(uint256 tokensBurned);
    // TODO more events? (deposit, withdraw)

    // Invariant: GYD balance of this == sum(adjustmentFactor * position.adjustedAmount for positionId, position in positions if positionId > lastFullBurnPositionId)

    IGyroConfig public immutable gyroConfig;
    IGYDToken public immutable gydToken;

    constructor(
        address _gyroConfig
    )
    {
        gyroConfig = IGYDToken(_gyroConfig);
        gydToken = gyroConfig.getGYDToken();
    }

    function totalUnderlying() public view returns(uint256)
    {
        return gydToken.balanceOf(address(this));
    }

    function deposit(uint256 amount) external
    {
        return depositFor(msg.sender, amount);
    }

    function depositFor(address beneficiary, uint256 amount) external returns (uint256 positionId)
    {
        gydToken.safeTransferFrom(msg.sender, address(this), amount);

        uint256 positionId = ++lastPositionId;
        uint256 adjustedAmount = amount.divDown(adjustmentFactor);
        positions[positionId] = Position({
            owner: beneficiary,
            depositedBlock: block.number,
            adjustedAmount: adjustedAmount
        });
        return positionId;
    }

    function withdraw(uint256 positionId) external returns (uint256 amount)
    {
        Position storage position = positions[positionId];
        require(position.owner == msg.sender);

        // TODO time locking / staking

        uint256 amount = positionId <= lastFullBurnPositionId ? 0 :position.adjustedAmount.mulDown(adjustmentFactor);

        gydToken.safeTransfer(msg.sender, amount);

        delete positions[positionId];
        return amount;
    }

    function amountLocked(uint256 positionId) external view returns (uint256 amount)
    {
        if (positionId <= lastFullBurnPositionId) {
            amount = 0;
        } else {
            Position storage position = positions[positionId];
            amount = position.adjustedAmount.mulDown(adjustmentFactor);
        }
    }

    function shouldRun(DataTypes.ReserveState reserveState) public view returns (bool)
    {
        uint256 currentCR = reserveState.totalUSDValue.divDown(gydToken.totalSupply());
        uint256 triggerCR = gyroConfig.getUint(ConfigKeys.GYD_RECOVERY_TRIGGER_CR);
        return currentCR < triggerCR;
    }

    /** @dev check if the recovery module should run, do it if needed. Can be called by anyone.
     * @return has run? */
    // TODO Should we set up any plumbing for interaction with the GYFI safety module (upcoming) already now? (maybe not)
    function checkAndRun(DataTypes.ReserveState reserveState) external returns (bool)
    {
        if (!shouldRun(reserveState))
            return false;

        // Compute amount to burn to reach target CR.
        uint256 targetCR = gyroConfig.getUint(ConfigKeys.GYD_RECOVERY_TARGET_CR);
        uint256 targetGYDSupply = reserveState.totalUSDValue.divDown(targetCR);
        uint256 currentGYDSupply = gydToken.totalSupply();

        if (targetGYDSupply >= currentGYDSupply) {
            // Sanity check. This can only happen if TARGET_CR < TRIGGER_CR, which is probably a buggy config.
            return false;
        }
        amountToBurn = currentGYDSupply - targetGYDSupply;

        // Check if we have enough GYD stored in this contract.
        uint256 _totalUnderlying = totalUnderlying();
        if (amountToBurn > _totalUnderlying) {
            amountToBurn = _totalUnderlying;
            lastFullBurnPositionId = lastPositionId;
            adjustmentFactor = FixedPoint.ONE;
        } else {
            adjustmentFactor = adjustmentFactor.mulDown(amountToBurn).divDown(totalAmountLocked);
        }

        gydToken.burn(amountToBurn);

        // TODO should we flag in the event when everything was burned? Should the original amount be in the event? (mostly for debug purposes)
        emit GydRecoveryRun(amountToBurn);

        return true;
    }
}
