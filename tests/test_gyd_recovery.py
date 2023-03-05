import pytest

from brownie.test.managers.runner import RevertContextManager as reverts

from tests.support.types import MintAsset
from tests.support.utils import scale

from tests.support import config_keys, constants

@pytest.fixture(scope="module", autouse=True)
def my_init(set_mock_oracle_prices_usdc_dai, set_fees_usdc_dai):
    pass


@pytest.fixture(scope="module")
def register_usdc_vault_module(reserve_manager, usdc_vault, admin):
    reserve_manager.registerVault(usdc_vault, scale(1), 0, 0, {"from": admin})


@pytest.fixture(scope="module")
def gyd_alice(motherboard, usdc, usdc_vault, alice, register_usdc_vault_module, set_mock_oracle_prices_usdc_dai, set_fees_usdc_dai, gyro_config):
    """Puts alice's USDC into GYD. Alice will hold 10 GYD afterwards."""
    usdc_amount = scale(10, usdc.decimals())
    usdc.approve(motherboard, usdc_amount, {"from": alice})
    mint_asset = MintAsset(
        inputToken=usdc, inputAmount=usdc_amount, destinationVault=usdc_vault
    )
    motherboard.mint([mint_asset], 0, {"from": alice})

@pytest.mark.usefixtures("gyd_alice")
def test_deposit(alice, gyd_recovery, gyd_token):
    # Simple "dummy" test
    gyd_amount = scale(2)
    gyd_token.approve(gyd_recovery, gyd_amount, {'from': alice})
    gyd_recovery.deposit(gyd_amount, {'from': alice})
    assert gyd_recovery.balanceOf(alice) == gyd_amount
