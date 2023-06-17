import pytest
from brownie.test.managers.runner import RevertContextManager as reverts
from brownie import interface  # type: ignore
from tests.support import config_keys, error_codes
from tests.support.quantized_decimal import DecimalLike
from tests.support.types import (
    PersistedVaultMetadata,
    VaultConfiguration,
    VaultInfo,
)
from tests.support.utils import scale


@pytest.fixture(autouse=True)
def set_vaults_prices(admin, mock_vaults, mock_price_oracle):
    for vault in mock_vaults:
        mock_price_oracle.setUSDPrice(vault.underlying(), scale(1), {"from": admin})
        mock_price_oracle.setUSDPrice(vault, scale(1), {"from": admin})


def _deposit_to_reserve(admin, vault, reserve, amount=scale(100)):
    underlying = interface.ERC20(vault.underlying())
    underlying.approve(vault, 2**256 - 1, {"from": admin})
    vault.deposit(amount, 0, {"from": admin})
    vault.approve(reserve, 2**256 - 1, {"from": admin})
    reserve.depositToken(vault, amount, {"from": admin})


def _make_vault_config(
    vault_address, fee_handler, weight: DecimalLike
) -> VaultConfiguration:
    fee_handler.setVaultFees(vault_address, 0, 0)
    return VaultConfiguration(
        vault_address=vault_address,
        metadata=PersistedVaultMetadata(
            price_at_calibration=scale(1),
            weight_at_calibration=int(scale(weight)),
            short_flow_memory=0,
            short_flow_threshold=0,
        ),
    )


def test_set_vaults(
    admin, reserve_manager, mock_vaults, reserve, static_percentage_fee_handler
):
    reserve_manager.setVaults(
        [
            _make_vault_config(mock_vaults[0], static_percentage_fee_handler, "0.5"),
            _make_vault_config(mock_vaults[1], static_percentage_fee_handler, "0.5"),
        ],
        {"from": admin},
    )
    _deposit_to_reserve(admin, mock_vaults[0], reserve)
    _deposit_to_reserve(admin, mock_vaults[1], reserve)
    total_usd, vaults = reserve_manager.getReserveState()
    assert len(vaults) == 2
    assert [VaultInfo(*v).vault for v in vaults] == mock_vaults[:2]
    assert total_usd == scale(200)
    reserve_manager.setVaults(
        [
            _make_vault_config(mock_vaults[0], static_percentage_fee_handler, "0.5"),
            _make_vault_config(mock_vaults[1], static_percentage_fee_handler, "0.4"),
            _make_vault_config(mock_vaults[2], static_percentage_fee_handler, "0.1"),
        ],
        {"from": admin},
    )
    total_usd, vaults = reserve_manager.getReserveState()
    assert len(vaults) == 3
    assert total_usd == scale(200)
    assert [VaultInfo(*v).vault for v in vaults] == mock_vaults[:3]


def test_cannot_remove_valuable_vault(
    admin,
    reserve_manager,
    mock_vaults,
    reserve,
    static_percentage_fee_handler,
    gyro_config,
):
    gyro_config.setUint(config_keys.VAULT_DUST_THRESHOLD, scale(100))
    reserve_manager.setVaults(
        [
            _make_vault_config(mock_vaults[0], static_percentage_fee_handler, "0.5"),
            _make_vault_config(mock_vaults[1], static_percentage_fee_handler, "0.5"),
        ],
        {"from": admin},
    )
    _deposit_to_reserve(admin, mock_vaults[0], reserve)
    _deposit_to_reserve(admin, mock_vaults[1], reserve)
    new_vaults = [
        _make_vault_config(mock_vaults[0], static_percentage_fee_handler, "1")
    ]
    with reverts(error_codes.VAULT_CANNOT_BE_REMOVED):
        reserve_manager.setVaults(
            new_vaults,
            {"from": admin},
        )


def test_can_remove_vault_with_dust(
    admin, reserve_manager, mock_vaults, reserve, static_percentage_fee_handler
):
    reserve_manager.setVaults(
        [
            _make_vault_config(mock_vaults[0], static_percentage_fee_handler, "0.5"),
            _make_vault_config(mock_vaults[1], static_percentage_fee_handler, "0.5"),
        ],
        {"from": admin},
    )
    _deposit_to_reserve(admin, mock_vaults[0], reserve)
    _deposit_to_reserve(admin, mock_vaults[1], reserve, amount=scale(5))
    total_usd, vaults = reserve_manager.getReserveState()
    assert total_usd == scale(105)

    new_vaults = [
        _make_vault_config(mock_vaults[0], static_percentage_fee_handler, "1")
    ]
    reserve_manager.setVaults(new_vaults, {"from": admin})
    total_usd, vaults = reserve_manager.getReserveState()
    assert len(vaults) == 1
    assert total_usd == scale(100)
    assert VaultInfo(*vaults[0]).vault == mock_vaults[0]
