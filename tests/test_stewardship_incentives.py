import pytest

from brownie.test.managers.runner import RevertContextManager as reverts
from brownie import chain

from tests.support.types import MintAsset
from tests.support.utils import scale, unscale, to_decimal

from tests.support import config_keys, constants

# TODO setup is very similar to test_gyd_recovery and test_motherboard. Perhaps find some common infrastructure.

@pytest.fixture(scope="module", autouse=True)
def my_init(set_mock_oracle_prices_usdc_dai, set_fees_usdc_dai):
    pass


@pytest.fixture(scope="module")
def register_dai_vault_module(reserve_manager, dai_vault, admin):
    reserve_manager.registerVault(dai_vault, scale(1), 0, 0, {"from": admin})


@pytest.fixture(scope="module")
def gyd_alice(motherboard, dai, dai_vault, alice, register_dai_vault_module, set_mock_oracle_prices_usdc_dai, set_fees_usdc_dai, gyro_config):
    """Puts alice's DAI into GYD. Alice will hold 10 GYD afterwards."""
    dai_amount = scale(5, dai.decimals())
    dai.approve(motherboard, dai_amount, {"from": alice})
    mint_asset = MintAsset(
        inputToken=dai, inputAmount=dai_amount, destinationVault=dai_vault
    )
    motherboard.mint([mint_asset], 0, {"from": alice})


@pytest.mark.usefixtures("gyd_alice")
def test_start(stewardship_incentives, gyd_token, admin, mock_price_oracle, dai, dai_vault, reserve_manager):
    # Manipulate reserve ratio to 120%
    mock_price_oracle.setUSDPrice(dai, scale("1.2"), {"from": admin})
    mock_price_oracle.setUSDPrice(dai_vault, scale("1.2"), {"from": admin})

    reward_percentage = scale("0.01")

    start_time = chain.time()
    end_time = start_time + constants.STEWARDSHIP_INC_DURATION

    tx = stewardship_incentives.startInitiative(reward_percentage, {'from': admin})
    assert tx.events['InitiativeStarted']['endTime'] == end_time
    assert tx.events['InitiativeStarted']['minCollateralRatio'] == constants.STEWARDSHIP_INC_MIN_CR
    assert tx.events['InitiativeStarted']['rewardPercentage'] == reward_percentage

    assert stewardship_incentives.activeInitiative() == (start_time, end_time, constants.STEWARDSHIP_INC_MIN_CR, constants.STEWARDSHIP_INC_MAX_VIOLATIONS, reward_percentage)

@pytest.mark.usefixtures("gyd_alice")
def test_start_end_const(stewardship_incentives, gyd_token, admin, mock_price_oracle, dai, dai_vault, reserve_manager, gyro_config, gov_treasury_registered):
    """Test from start to end without any shock or supply change"""
    # Manipulate reserve ratio to 120%
    mock_price_oracle.setUSDPrice(dai, scale("1.2"), {"from": admin})
    mock_price_oracle.setUSDPrice(dai_vault, scale("1.2"), {"from": admin})

    # Start incentive (same as above)
    reward_percentage = to_decimal("0.01")
    reward_percentage_scaled = scale(reward_percentage)
    stewardship_incentives.startInitiative(reward_percentage_scaled, {'from': admin})

    chain.sleep(constants.STEWARDSHIP_INC_DURATION)
    chain.mine()

    reward_expd_scaled = gyd_token.totalSupply() * reward_percentage

    tx = stewardship_incentives.completeInitiative()
    assert tx.events['InitiativeCompleted']['rewardGYDAmount'] == reward_expd_scaled
    assert tx.events['Transfer']['from'] == "0x0000000000000000000000000000000000000000"
    assert tx.events['Transfer']['to'] == gov_treasury_registered
    assert tx.events['Transfer']['value'] == reward_expd_scaled

@pytest.mark.usefixtures("gyd_alice")
def test_start_end_supplychange(stewardship_incentives, gyd_token, admin, mock_price_oracle, dai, dai_vault, reserve_manager, gyro_config, gov_treasury_registered, motherboard, alice):
    """Test from start to end, change supply in the middle."""
    mock_price_oracle.setUSDPrice(dai, scale("1.2"), {"from": admin})
    mock_price_oracle.setUSDPrice(dai_vault, scale("1.2"), {"from": admin})

    # Start incentive (same as above)
    reward_percentage = to_decimal("0.01")
    reward_percentage_scaled = scale(reward_percentage)
    stewardship_incentives.startInitiative(reward_percentage_scaled, {'from': admin})

    gyd_supply0 = unscale(gyd_token.totalSupply())

    chain.sleep(constants.STEWARDSHIP_INC_DURATION // 2)
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

    gyd_supply1 = unscale(gyd_token.totalSupply())
    chain.sleep(constants.STEWARDSHIP_INC_DURATION // 2)
    chain.mine()

    avg_gyd_supply = (gyd_supply0 + gyd_supply1) / 2

    # Now complete the initiative
    tx = stewardship_incentives.completeInitiative()

    reward_expected = avg_gyd_supply * reward_percentage
    reward_actual = unscale(tx.events['InitiativeCompleted']['rewardGYDAmount'])
    assert reward_actual <= reward_expected and reward_actual == reward_expected.approxed()
    assert stewardship_incentives.reserveHealthViolations()[1] == 1  # nViolations
