from typing import Optional
import pytest
from brownie import accounts
from brownie.test.managers.runner import RevertContextManager as reverts
from tests.support import error_codes
from tests.support.config_keys import RESERVE_MANAGER_ADDRESS
from tests.support.quantized_decimal import DecimalLike
from tests.support.types import PersistedVaultMetadata, VaultConfiguration
from tests.support.utils import scale


@pytest.fixture(autouse=True)
def set_reserve_manager(admin, gyro_config):
    gyro_config.setAddress(RESERVE_MANAGER_ADDRESS, admin, {"from": admin})


@pytest.fixture(scope="module")
def make_vault_config(admin, MockGyroVault, dai, static_percentage_fee_handler):
    def _make_vault_config(
        weight: DecimalLike, vault_address: Optional[str] = None
    ) -> VaultConfiguration:
        if vault_address is None:
            vault = admin.deploy(MockGyroVault)
            vault.initialize(dai)
            vault_address = vault.address
        assert vault_address is not None
        static_percentage_fee_handler.setVaultFees(vault_address, 0, 0)
        return VaultConfiguration(
            vault_address=vault_address,
            metadata=PersistedVaultMetadata(int(scale(1)), int(scale(weight)), 0, 0),
        )

    return _make_vault_config


def test_set_vaults(admin, make_vault_config, vault_registry):
    vaults = [make_vault_config(w) for w in ["0.3", "0.2", "0.5"]]
    vault_registry.setVaults(vaults, {"from": admin})
    assert vault_registry.listVaults() == [v.vault_address for v in vaults]


def test_set_vaults_schedule(admin, make_vault_config, vault_registry, chain):
    vaults = [make_vault_config(w) for w in ["0.3", "0.2", "0.5"]]

    vault_registry.setVaults(vaults, {"from": admin})

    vaults = [
        make_vault_config(weight, vault_address=vault.vault_address)
        for vault, weight in zip(vaults, ["0.6", "0.2", "0.2"])
    ]
    vault_registry.setVaults(vaults, {"from": admin})

    chain.sleep(86400)
    chain.mine()

    assert vault_registry.getScheduleVaultWeight(
        vaults[0].vault_address
    ) / 1e18 == pytest.approx(0.3 + 0.3 / 7, rel=1e-4)
    assert vault_registry.getScheduleVaultWeight(vaults[1].vault_address) / 1e18 == 0.2
    assert vault_registry.getScheduleVaultWeight(
        vaults[2].vault_address
    ) / 1e18 == pytest.approx(0.5 - 0.3 / 7, rel=1e-4)

    chain.sleep(4 * 86400)
    chain.mine()

    assert vault_registry.getScheduleVaultWeight(
        vaults[0].vault_address
    ) / 1e18 == pytest.approx(0.3 + 0.3 * 5 / 7, rel=1e-4)
    assert vault_registry.getScheduleVaultWeight(vaults[1].vault_address) / 1e18 == 0.2
    assert vault_registry.getScheduleVaultWeight(
        vaults[2].vault_address
    ) / 1e18 == pytest.approx(0.5 - 0.3 * 5 / 7, rel=1e-4)

    chain.sleep(3 * 86400)
    chain.mine()

    assert vault_registry.getScheduleVaultWeight(vaults[0].vault_address) / 1e18 == 0.6
    assert vault_registry.getScheduleVaultWeight(vaults[1].vault_address) / 1e18 == 0.2
    assert vault_registry.getScheduleVaultWeight(vaults[2].vault_address) / 1e18 == 0.2


def test_set_vaults_weights_not_summing_to_1(admin, make_vault_config, vault_registry):
    vaults = [make_vault_config(w) for w in ["0.7", "0.2", "0.5"]]
    with reverts(error_codes.INVALID_ARGUMENT):
        vault_registry.setVaults(vaults, {"from": admin})


def test_set_vaults_duplicate(admin, make_vault_config, vault_registry):
    vault_config = make_vault_config("0.5")
    vaults = [vault_config, vault_config]
    with reverts(error_codes.INVALID_ARGUMENT):
        vault_registry.setVaults(vaults, {"from": admin})


def test_set_vaults_unordered_tokens(
    admin, make_vault_config, vault_registry, MockGyroVault
):
    vaults = [make_vault_config(w) for w in ["0.5", "0.5"]]
    vault = MockGyroVault.at(vaults[0].vault_address)
    vault.setTokens(
        sorted([v.vault_address for v in vaults], reverse=True, key=lambda a: a.lower())
    )
    with reverts(error_codes.TOKENS_NOT_SORTED):
        vault_registry.setVaults(vaults, {"from": admin})
