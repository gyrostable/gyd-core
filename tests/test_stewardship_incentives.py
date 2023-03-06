import pytest

from brownie.test.managers.runner import RevertContextManager as reverts
from brownie import chain

from tests.support.types import MintAsset
from tests.support.utils import scale

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
    dai_amount = scale(10, dai.decimals())
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

    time0 = chain.time()

    tx = stewardship_incentives.startInitiative(reward_percentage, {'from': admin})
    assert tx.events['InitiativeStarted']['endTime'] == time0 + constants.STEWARDSHIP_INC_DURATION
    assert tx.events['InitiativeStarted']['minCollateralRatio'] == constants.STEWARDSHIP_INC_MIN_CR
    assert tx.events['InitiativeStarted']['rewardPercentage'] == reward_percentage

    assert stewardship_incentives.activeInitiative()[0] == time0
