import pytest

from brownie.test.managers.runner import RevertContextManager as reverts
from brownie import chain
from tests.fixtures.deployments import (
    STEWARDSHIP_INC_DURATION,
    STEWARDSHIP_INC_MAX_VIOLATIONS,
    STEWARDSHIP_INC_MIN_CR,
)

from tests.support.types import (
    MintAsset,
    PersistedVaultMetadata,
    VaultConfiguration,
)
from tests.support.utils import scale, unscale, to_decimal

from tests.support import config_keys, constants

# TODO setup is very similar to test_gyd_recovery and test_motherboard. Perhaps find some common infrastructure.


@pytest.fixture(scope="module", autouse=True)
def my_init(set_mock_oracle_prices_usdc_dai, set_fees_usdc_dai):
    pass


@pytest.fixture(scope="module")
def register_dai_vault_module(reserve_manager, dai_vault, admin):
    reserve_manager.setVaults(
        [
            VaultConfiguration(
                dai_vault, PersistedVaultMetadata(int(scale(1)), int(scale(1)), 0, 0)
            )
        ],
        {"from": admin},
    )


@pytest.fixture(scope="module")
def gyd_alice(
    motherboard,
    dai,
    dai_vault,
    alice,
    register_dai_vault_module,
    set_mock_oracle_prices_usdc_dai,
    set_fees_usdc_dai,
    gyro_config,
):
    """Puts alice's DAI into GYD. Alice will hold 10 GYD afterwards."""
    dai_amount = scale(5, dai.decimals())
    dai.approve(motherboard, dai_amount, {"from": alice})
    mint_asset = MintAsset(
        inputToken=dai, inputAmount=dai_amount, destinationVault=dai_vault
    )
    motherboard.mint([mint_asset], 0, {"from": alice})


@pytest.mark.usefixtures("gyd_alice")
def test_start(
    stewardship_incentives,
    gyd_token,
    admin,
    mock_price_oracle,
    dai,
    dai_vault,
    reserve_manager,
):
    # Manipulate reserve ratio to 120%
    mock_price_oracle.setUSDPrice(dai, scale("1.2"), {"from": admin})
    mock_price_oracle.setUSDPrice(dai_vault, scale("1.2"), {"from": admin})

    reward_percentage = scale("0.01")

    tx = stewardship_incentives.startInitiative(reward_percentage, {"from": admin})
    start_time = tx.timestamp
    end_time = start_time + STEWARDSHIP_INC_DURATION
    assert tx.events["InitiativeStarted"]["endTime"] == end_time
    assert (
        tx.events["InitiativeStarted"]["minCollateralRatio"] == STEWARDSHIP_INC_MIN_CR
    )
    assert tx.events["InitiativeStarted"]["rewardPercentage"] == reward_percentage

    assert stewardship_incentives.activeInitiative() == (
        start_time,
        end_time,
        STEWARDSHIP_INC_MIN_CR,
        STEWARDSHIP_INC_MAX_VIOLATIONS,
        reward_percentage,
    )


@pytest.mark.usefixtures("gyd_alice")
def test_start_end_const(
    stewardship_incentives,
    gyd_token,
    admin,
    mock_price_oracle,
    dai,
    dai_vault,
    reserve_manager,
    gyro_config,
    gov_treasury_registered,
):
    """Test from start to end without any shock or supply change"""
    # Manipulate reserve ratio to 120%
    mock_price_oracle.setUSDPrice(dai, scale("1.2"), {"from": admin})
    mock_price_oracle.setUSDPrice(dai_vault, scale("1.2"), {"from": admin})

    # Start incentive (same as above)
    reward_percentage = to_decimal("0.01")
    reward_percentage_scaled = scale(reward_percentage)
    stewardship_incentives.startInitiative(reward_percentage_scaled, {"from": admin})

    chain.sleep(STEWARDSHIP_INC_DURATION)
    chain.mine()

    reward_expd_scaled = gyd_token.totalSupply() * reward_percentage

    tx = stewardship_incentives.completeInitiative()
    assert tx.events["InitiativeCompleted"]["rewardGYDAmount"] == reward_expd_scaled
    assert tx.events["Transfer"]["from"] == "0x0000000000000000000000000000000000000000"
    assert tx.events["Transfer"]["to"] == gov_treasury_registered
    assert tx.events["Transfer"]["value"] == reward_expd_scaled


@pytest.mark.usefixtures("gyd_alice")
def test_start_end_supplychange(
    stewardship_incentives,
    gyd_token,
    admin,
    mock_price_oracle,
    dai,
    dai_vault,
    reserve_manager,
    gyro_config,
    gov_treasury_registered,
    motherboard,
    alice,
):
    """Test from start to end, change supply in the middle and match avg supply."""
    mock_price_oracle.setUSDPrice(dai, scale("1.2"), {"from": admin})
    mock_price_oracle.setUSDPrice(dai_vault, scale("1.2"), {"from": admin})

    # Start incentive (same as above)
    reward_percentage = to_decimal("0.01")
    reward_percentage_scaled = scale(reward_percentage)
    stewardship_incentives.startInitiative(reward_percentage_scaled, {"from": admin})

    gyd_supply0 = unscale(gyd_token.totalSupply())

    chain.sleep(STEWARDSHIP_INC_DURATION // 2)
    chain.mine()

    # Create additional GYD. We drop the price and mint. This means that this will be our one day where
    # health violation is allowed.
    mock_price_oracle.setUSDPrice(dai, scale("1.0"), {"from": admin})
    mock_price_oracle.setUSDPrice(dai_vault, scale("1.0"), {"from": admin})

    dai_amount = scale(5, dai.decimals())
    dai.approve(motherboard, dai_amount, {"from": alice})
    mint_asset = MintAsset(
        inputToken=dai, inputAmount=dai_amount, destinationVault=dai_vault
    )
    motherboard.mint([mint_asset], 0, {"from": alice})

    mock_price_oracle.setUSDPrice(dai, scale("1.2"), {"from": admin})
    mock_price_oracle.setUSDPrice(dai_vault, scale("1.2"), {"from": admin})

    # If we try to complete now, that's gonna fail
    with reverts("initiative not yet complete"):
        stewardship_incentives.completeInitiative()

    gyd_supply1 = unscale(gyd_token.totalSupply())
    chain.sleep(STEWARDSHIP_INC_DURATION // 2)
    chain.mine()

    avg_gyd_supply = (gyd_supply0 + gyd_supply1) / 2

    # Now complete the initiative
    tx = stewardship_incentives.completeInitiative()

    reward_expected = avg_gyd_supply * reward_percentage
    reward_actual = unscale(tx.events["InitiativeCompleted"]["rewardGYDAmount"])
    assert (
        reward_actual <= reward_expected and reward_actual == reward_expected.approxed()
    )
    assert stewardship_incentives.reserveHealthViolations()[1] == 1  # nViolations


@pytest.mark.usefixtures("gyd_alice")
def test_violations(
    stewardship_incentives,
    gyd_token,
    admin,
    mock_price_oracle,
    dai,
    dai_vault,
    reserve_manager,
    gyro_config,
    gov_treasury_registered,
    motherboard,
    alice,
):
    """Test with multiple reserve violations so withdrawal fails."""
    """Test from start to end, change supply in the middle and match avg supply."""
    mock_price_oracle.setUSDPrice(dai, scale("1.2"), {"from": admin})
    mock_price_oracle.setUSDPrice(dai_vault, scale("1.2"), {"from": admin})

    # Start incentive (same as above)
    reward_percentage = to_decimal("0.01")
    reward_percentage_scaled = scale(reward_percentage)
    stewardship_incentives.startInitiative(reward_percentage_scaled, {"from": admin})

    gyd_supply0 = unscale(gyd_token.totalSupply())

    chain.sleep(25 * 60 * 60)
    chain.mine()

    # We set reserve ratio to 1, which is < 1.05 = min reserve ratio. We then let two days pass and call checkpoint() to update.
    mock_price_oracle.setUSDPrice(dai, scale("1.0"), {"from": admin})
    mock_price_oracle.setUSDPrice(dai_vault, scale("1.0"), {"from": admin})

    stewardship_incentives.checkpoint()
    chain.sleep(25 * 60 * 60)
    chain.mine()

    stewardship_incentives.checkpoint()
    chain.sleep(25 * 60 * 60)
    chain.mine()

    assert stewardship_incentives.reserveHealthViolations()[1] == 2
    assert stewardship_incentives.hasFailed()

    # Let enough time pass and try to complete. This will fail.
    chain.sleep(STEWARDSHIP_INC_DURATION)
    chain.mine()

    with reverts("initiative failed: too many health violations"):
        stewardship_incentives.completeInitiative()
