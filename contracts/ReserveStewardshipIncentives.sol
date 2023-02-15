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
    uint internal constant MAX_HEALTH_VIOLATIONS = 1;  // TODO could be configurable

    struct Proposal {
        uint256 startTime;  // timestamp (not block)
        uint256 endTime;  // timestamp (not block)
        // SOMEDAY optimization: could be stored with fewer bits to save a slot
        uint256 minCollateralRatio;
        uint256 rewardPercentage;
    }
    Proposal public activeProposal;  // .endTime = 0 means none is there.

    struct ReserveHealthViolations {
        // SOMEDAY optimization: could be stored with fewer bits to save a slot
        uint256 lastViolatedDate;  // date
        uint256 nViolations;
    }
    ReserveHealthViolations reserveHealthViolations;

    // We store the time integral of the GYD supply to compute the reward at the end based on avg supply.
    struct AggSupply {
        uint256 lastUpdatedTimestamp;
        uint256 aggSupply;
    }
    AggSupply public aggSupply;

    IGyroConfig public immutable gyroConfig;
    IGYDToken public immutable gydToken;

    // TODO some events, raise below.

    constructor(address _governor, address _gyroConfig) Governable(_governor)
    {
        gyroConfig = IGyroConfig(_gyroConfig);
        gydToken = gyroConfig.getGYDToken();
    }

    // TODO should the rewardPercentage be an argument to this fct or a GyroConfig variable? I feel *probably* here but
    // flagging.
    /** @dev Create new incentive proposal.
     * @param rewardPercentage Share of the average GYD supply over time that should be paid as a reward.
    */
    function createProposal(uint256 rewardPercentage) external governanceOnly
    {
        require(rewardPercentage <= MAX_REWARD_PERCENTAGE);
        require(!activeProposal.endTime);

        // TODO code these config keys and access methods
        uint256 minCollateralRatio = gyroConfig.getIncentiveMinCollateralRatio();
        uint256 duration = gyroConfig.getIncentiveDuration();

        DataTypes.ReserveState memory reserveState = gyroConfig.getReserveManager().getReserveState();
        uint256 gydSupply = gydToken.totalSupply();

        uint256 collateralRatio = reserveState.totalUSDValue.divDown(gydSupply);
        require(collateralRatio >= minCollateralRatio);

        uint256 today = timestampToDatestamp(block.timestamp);
        reserveHealthViolations = ReserveHealthViolations(0, 0);

        aggSupply = AggSupply(block.timestamp, 0);  // init at 0 because it's aggregate over time.

        activeProposal = Proposal({
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            minCollateralRatio: minCollateralRatio,
            rewardPercentage: rewardPercentage
        });
    }

    function cancelActiveProposal() external governanceOnly {
        activeProposal.endTime = 0;
    }

    // TODO should this be governanceOnly? Should it an address to send the funds to as an argument?
    function completeActiveProposal() external {
        uint256 endTime = activeProposal.endTime;
        require(endTime > 0 && endTime <= block.timestamp);

        // TODO add view methods for easier checking by others. Then use these functions, too, here.
        
        // Check incentive success
        require(reserveHealthViolations.nViolations <= MAX_HEALTH_VIOLATIONS);

        // Compute target reward
        uint256 proposalLength = aggSupply.lastUpdatedTimestamp - activeProposal.startTime;
        uint256 avgGYDSupply = aggSupply.aggSupply / proposalLength;
        uint256 targetReward = activeProposal.rewardPercentage.mulDown(avgGYDSupply);

        // Compute max available reward
        DataTypes.ReserveState reserveState = gyroConfig.getReserveManager().getReserveState();
        uint256 gydSupply = gydToken.totalSupply();
        // TODO should this pull the *current* min collateralization ratio from config instead in case it was changed?
        uint256 maxAllowedGYDSupply = reserveState.totalUSDValue.divDown(activeProposal.minCollateralRatio);
        // If the following fails, collateralization ratio fell too low between the last update and now.
        require(gydSupply < maxAllowedGYDSupply);
        uint256 maxReward = maxAllowedGYDSupply - gydSupply;

        // Marry target reward with max available reward. We could take the minimum here but we use a slightly different
        // function to incentivize governance towards moderation when choosing rewardPercentage.
        // TODO still a bit open what exactly the formula should be. This one introduces a linear penalty for over-estimation.
        uint256 reward = targetReward;
        if (reward > maxReward) {
            uint256 reduction = (FixedPoint.ONE + OVERESTIMATION_PENALTY_FACTOR).mulDown(reward - maxReward);
            reward = reduction < reward ? reward - reduction : 0;
        }

        // TODO mint `reward` new GYD out of thin air and credit them to governance treasury (tbd)

        activeProposal.endTime = 0;
    }

    function updateTrackedVariables(DataTypes.ReserveState memory reserveState) public
    {
        if (!activeProposal.endTime || activeProposal.endTime <= block.timestamp)
            // NB it's important to not track anything after the proposal has ended: may introduce manipulability.
            return;

        uint256 gydSupply = gydToken.totalSupply();
        uint256 lastUpdated = aggSupply.lastUpdatedTimestamp;
        if (block.timestamp > lastUpdated) {  // Check to handle timestamp fluctuations
            aggSupply.aggSupply += (block.timestamp - lastUpdated) * gydSupply;
            aggSupply.lastUpdatedTimestamp = block.timestamp;
        }
        
        uint256 collateralRatio = reserveState.totalUSDValue.divDown(gydSupply);
        if (collateralRatio < activeProposal.minCollateralRatio) {
            uint256 today = timestampToDatestamp(block.timestamp);
            if (reserveHealthViolations.lastViolatedDate < today) {
                ++reserveHealthViolations.nViolations;
                reserveHealthViolations.lastViolatedDate = today;
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
