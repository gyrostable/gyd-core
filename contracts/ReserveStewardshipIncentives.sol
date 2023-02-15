pragma solidity ^0.8.0;

import "./auth/Governable.sol";
import "../interfaces/IGyroConfig.sol";
import "../interfaces/IGYDToken.sol";
import "../libraries/ConfigHelpers.sol";
import "../libraries/FixedPoint.sol";

contract ReserveStewardshipIncentives is Governable {
    using ConfigHelpers for IGyroConfig;
    using FixedPoint for uint256;

    uint internal constant SECONDS_PER_DAY = 24 * 60 * 60;

    uint internal constant MAX_REWARD_PERCENTAGE = 0.5e18;
    uint internal constant OVERESTIMATION_PENALTY_FACTOR = 0.1e18;

    struct Proposal {
        uint256 startTime;  // timestamp (not block)
        uint256 endTime;  // timestamp (not block)
        // SOMEDAY optimization: could be stored with fewer bits to save a slot
        uint256 minCollateralizationRatio;
        uint256 rewardPercentage;
    }
    Proposal public activeProposal;  // activeProposal.endTime = 0 means none is there.

    // To track the second lowest collateralization ratio, we store two otherwise equal (date, CR) slots.
    struct CollateralizationAtDate {
        // SOMEDAY optimization date and CR could have fewer bits to pack into one slot.
        uint256 date; // days since unix epoch
        uint256 collateralizationRatio;
    }
    struct ReserveHealth {
        CollateralizationAtDate a;
        CollateralizationAtDate b;
    }
    ReserveHealth public reserveHealth;

    // We store the time integral of the GYD supply to compute the reward at the end based on avg supply.
    struct SupplyIntegral {
        uint256 lastUpdatedTimestamp;
        uint256 supply;
    }
    SupplyIntegral public supplyIntegral;

    IGyroConfig public immutable gyroConfig;
    IGYDToken public immutable gydToken;

    // TODO some events

    constructor(address _gyroConfig)
    {
        gyroConfig = IGyroConfig(_gyroConfig);
        gydToken = gyroConfig.getGYDToken();
    }

    // TODO should the rewardPercentage be an argument to this fct or a GyroConfig variable? I feel *probably* here but
    //   flagging.
    function createProposal(uint256 rewardPercentage) external governanceOnly
    {
        require(!activeProposal.endTime);  // currently no proposal running
        require(rewardPercentage <= MAX_REWARD_PERCENTAGE);

        uint256 minCollateralizationRatio = gyroConfig.getIncentiveMinCollateralizationRatio();
        uint256 duration = gyroConfig.getIncentiveDuration();

        // TODO Check proposal validity (depends on what the condition will be exactly)
        // TODO pull reserve state from reserve manager (this is easy)
        DataTypes.ReserveState reserveState;

        uint256 gydSupply = gydToken.totalSupply();

        uint256 collateralizationRatio = reserveState.totalUSDValue.divDown(gydSupply);
        require(collateralizationRatio >= minCollateralizationRatio);

        uint256 date = timestampToDatestamp(block.timestamp);
        reserveHealth = ReserveHealth({
            a: CollateralizationAtDate(date, collateralizationRatio),
            b: CollateralizationAtDate(date, collateralizationRatio)
        });

        supplyIntegral = SupplyIntegral(block.timestamp, gydSupply);

        activeProposal = Proposal({
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            minCollateralizationRatio: minCollateralizationRatio,
            rewardPercentage: rewardPercentage
        });
    }

    function cancelActiveProposal() external governanceOnly {
        activeProposal.endTime = 0;
    }

    // TODO should this be governanceOnly?
    function completeActiveProposal() external {
        uint256 endTime = activeProposal.endTime;
        require(endTime > 0 && endTime <= block.timestamp);

        // TODO add we have view methods for easier checking by others.
        
        // Check incentive success
        uint256 crA = reserveHealth.a.collateralizationRatio;
        uint256 crB = reserveHealth.b.collateralizationRatio;
        uint256 secondLowestDailyCR = crA >= crB ? crA : crB;
        require(secondLowestDailyCR >= activeProposal.minCollateralizationRatio);

        // Compute target reward
        uint256 proposalLength = block.timestamp - activeProposal.startTime;
        uint256 avgGYDSupply = supplyIntegral.supply / proposalLength;
        uint256 targetReward = activeProposal.rewardPercentage.mulDown(avgGYDSupply);

        // Compute max available reward
        // TODO should this be in relative terms? Does it matter?
        // TODO fetch reserve state
        DataTypes.ReserveState reserveState;
        uint256 gydSupply = gydToken.totalSupply();
        uint256 maxAllowedGYDSupply = reserveState.totalUSDValue.divDown(
            FixedPoint.ONE + activeProposal.rewardPercentage);
        // If the following fails, collateralization ratio fell too low between the last update and now.
        require(gydSupply < maxAllowedGYDSupply);
        uint256 maxReward = maxAllowedGYDSupply - gydSupply;

        // Marry target reward with max available reward. We could take the minimum here but we use
        // a slightly different function.
        // TODO open what exactly the formula should be. This one introduces a linear penalty for over-estimation.
        uint256 reward = targetReward;
        if (reward > maxReward) {
            uint256 reduction = (FixedPoint.ONE + OVERESTIMATION_PENALTY_FACTOR).mulDown(maxReward - targetReward);
            reward = reduction < maxReward ? maxReward - reduction : 0;
        }

        // TODO mint `reward` new GYD out of thin air and transfer them to governance treasury

        // End proposal
        activeProposal.endTime = 0;
    }

    function updateTrackedVariables(DataTypes.ReserveState memory reserveState) public
    {
        uint256 gydSupply = gydToken.totalSupply();
        
        uint256 lastUpdated = supplyIntegral.lastUpdatedTimestamp;
        if (block.timestamp > lastUpdated) {
            // Might fail b/c of short-term fluctuations of the timestamp
            supplyIntegral.supply += (block.timestamp - supplyIntegral.lastUpdatedTimestamp) * gydSupply;
            supplyIntegral.lastUpdatedTimestamp = block.timestamp;
        }
        
        uint256 collateralizationRatio = reserveState.totalUSDValue.divDown(gydSupply);

        uint256 today = timestampToDatestamp(block.timestamp);
        // TODO gas-optimize reads
        // We check for "today" using ">=" to handle timestamp fluctuations.
        if (reserveHealth.a.date >= today) {
            if (reserveHealth.a.collateralizationRatio > collateralizationRatio)
                reserveHealth.a.collateralizationRatio = collateralizationRatio;
        if (reserveHealth.b.date >= today) {
            if (reserveHealth.b.collateralizationRatio > collateralizationRatio)
                reserveHealth.b.collateralizationRatio = collateralizationRatio;
        } else {
            ReserveHealth storage lower;
            if (reserveHealth.a.collateralizationRatio < reserveHealth.b.collateralizationRatio)
                lower = reserveHealth.a;
            else
                lower = reserveHealth.b;
            if (lower.collateralizationRatio > collateralizationRatio) {
                lower.date = today;
                lower.collateralizationRatio = collateralizationRatio;
            }
        }
    }

    function updateTrackedVariables() external
    {
        DataTypes.ReserveState memory reserveState = gyroConfig
            .getReserveManager()
            .getReserveState();
        updateTrackedVariables(reserveState);
    }

    /// @dev Approximately days since epoch. Not quite correct but good enough to distinguish different
    /// days, which is all we need here.
    function timestampToDatestamp(uint256 timestamp) returns (uint256)
    {
        return timestamp / SECONDS_PER_DAY;
    }
}
