import pytest
from brownie import accounts
from brownie.test.managers.runner import RevertContextManager as reverts
from tests.support import error_codes
from tests.support.config_keys import RESERVE_MANAGER_ADDRESS
from tests.support.quantized_decimal import DecimalLike
from tests.support.types import PersistedVaultMetadata, VaultInternalConfiguration
from tests.support.utils import scale


@pytest.fixture(autouse=True)
def set_reserve_manager(admin, gyro_config):
    gyro_config.setAddress(RESERVE_MANAGER_ADDRESS, admin, {"from": admin})


def _make_vault_config(fee_handler, weight: DecimalLike) -> VaultInternalConfiguration:
    vault_address = accounts.add()
    fee_handler.setVaultFees(vault_address, 0, 0)
    return VaultInternalConfiguration(
        vault_address=vault_address.address,
        metadata=PersistedVaultMetadata(0, int(scale(weight)), 0, 0),
    )


def test_set_vaults(admin, vault_registry, static_percentage_fee_handler):
    vaults = [
        _make_vault_config(static_percentage_fee_handler, "0.3"),
        _make_vault_config(static_percentage_fee_handler, "0.2"),
        _make_vault_config(static_percentage_fee_handler, "0.5"),
    ]
    vault_registry.setVaults(vaults, {"from": admin})
    assert vault_registry.listVaults() == [v.vault_address for v in vaults]


def test_set_vaults_weights_not_summing_to_1(
    admin, vault_registry, static_percentage_fee_handler
):
    vaults = [
        _make_vault_config(static_percentage_fee_handler, "0.7"),
        _make_vault_config(static_percentage_fee_handler, "0.2"),
        _make_vault_config(static_percentage_fee_handler, "0.5"),
    ]
    with reverts(error_codes.INVALID_ARGUMENT):
        vault_registry.setVaults(vaults, {"from": admin})


def test_set_vaults_duplicate(admin, vault_registry, static_percentage_fee_handler):
    vault_config = _make_vault_config(static_percentage_fee_handler, "0.5")
    vaults = [vault_config, vault_config]
    with reverts(error_codes.INVALID_ARGUMENT):
        vault_registry.setVaults(vaults, {"from": admin})
