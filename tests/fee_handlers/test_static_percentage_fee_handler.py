from decimal import Decimal
from typing import Iterable, Tuple

import pytest
from brownie import Contract
from brownie.test.managers.runner import RevertContextManager as reverts
from tests.support import error_codes
from tests.support.types import (
    Order,
    PersistedVaultMetadata,
    VaultInfo,
    VaultWithAmount,
)
from tests.support.utils import scale

VAULT_FEES = [
    (Decimal("0.05"), Decimal("0.08")),
    (Decimal("0.002"), Decimal("0.001")),
    (Decimal("0.02"), Decimal("0")),
]


def _create_order(vault_amounts: Iterable[Tuple[Contract, int]], mint: bool) -> Order:
    vault_with_amounts = [
        VaultWithAmount(
            vault_info=VaultInfo(
                vault=vault.address,
                decimals=18,
                underlying=vault.underlying(),
                price=0,
                persisted_metadata=PersistedVaultMetadata(int(scale(1)), 0, 0, 0),
                reserve_balance=0,
                current_weight=0,
                target_weight=0,
                priced_tokens=[],
            ),
            amount=amount,
        )
        for vault, amount in vault_amounts
    ]
    return Order(vaults_with_amount=vault_with_amounts, mint=mint)


@pytest.fixture(scope="module")
def mock_vaults(MockGyroVault, admin, dai):
    def _deploy():
        vault = admin.deploy(MockGyroVault)
        vault.initialize(dai)
        return vault

    return [_deploy() for _ in range(3)]


@pytest.fixture(scope="module", autouse=True)
def set_fees(static_percentage_fee_handler, mock_vaults, admin):
    for i, mock_vault in enumerate(mock_vaults):
        static_percentage_fee_handler.setVaultFees(
            mock_vault, *[scale(v) for v in VAULT_FEES[i]], {"from": admin}
        )


@pytest.mark.parametrize("mint", [True, False])
def test_apply_fees(static_percentage_fee_handler, mock_vaults, mint):
    amounts = [int(v) for v in [scale("10000"), scale("2000"), scale("3500")]]
    order = _create_order(zip(mock_vaults, amounts), mint=mint)
    foo = static_percentage_fee_handler.applyFees(order)
    order_after_fees = Order.from_tuple(foo)

    assert order_after_fees.mint == mint
    assert len(order_after_fees.vaults_with_amount) == 3
    for i, (vault_info, amount) in enumerate(order_after_fees.vaults_with_amount):
        assert vault_info.vault == mock_vaults[i].address
        assert vault_info == order.vaults_with_amount[i].vault_info
        assert amount <= amounts[i]
        fee = VAULT_FEES[i][0 if mint else 1]
        assert amount == amounts[i] - int(fee * amounts[i])


def test_set_fee_to_high(static_percentage_fee_handler, mock_vaults, admin):
    max_fee = scale("0.2")
    with reverts(error_codes.INVALID_ARGUMENT):
        static_percentage_fee_handler.setVaultFees(
            mock_vaults[0], max_fee + 1, 0, {"from": admin}
        )

    with reverts(error_codes.INVALID_ARGUMENT):
        static_percentage_fee_handler.setVaultFees(
            mock_vaults[0], 0, max_fee + 1, {"from": admin}
        )
