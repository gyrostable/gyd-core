import pytest
from brownie import ZERO_ADDRESS
from brownie.test.managers.runner import RevertContextManager as reverts

from tests.support.types import (
    FlowDirection,
    Order,
    VaultConfiguration,
    VaultWithAmount,
    VaultInfo,
    PersistedVaultMetadata,
)
from tests.support import config_keys
from tests.support import error_codes
from tests.support.utils import scale


def _create_vault_info(admin, MockGyroVault, decimals, short_flow_threshold):
    vault = admin.deploy(MockGyroVault, ZERO_ADDRESS)
    return VaultInfo(
        vault=vault,
        current_weight=0,
        decimals=decimals,
        price=0,
        target_weight=0,
        persisted_metadata=PersistedVaultMetadata(
            price_at_last_calibration=int(scale(1)),
            short_flow_memory=int(scale("0.9", 18)),
            weight_at_last_calibration=int(scale("0.5", 18)),
            short_flow_threshold=short_flow_threshold,
        ),
        priced_tokens=[],
        reserve_balance=0,
        underlying=ZERO_ADDRESS,
    )


@pytest.fixture
def authorize_admin(admin, gyro_config):
    gyro_config.setAddress(
        config_keys.ROOT_SAFETY_CHECK_ADDRESS, admin.address, {"from": admin}
    )


@pytest.mark.usefixtures("authorize_admin")
@pytest.mark.parametrize("mint", [True, False])
def test_call_wrong_function(admin, vault_safety_mode, mint):
    order = Order(mint=mint, vaults_with_amount=[])
    query_check = (
        vault_safety_mode.isRedeemSafe if mint else vault_safety_mode.isMintSafe
    )
    execute_check = (
        vault_safety_mode.checkAndPersistRedeem
        if mint
        else vault_safety_mode.checkAndPersistMint
    )
    assert query_check(order) == error_codes.INVALID_ARGUMENT
    with reverts(error_codes.INVALID_ARGUMENT):
        execute_check(order, {"from": admin})


@pytest.mark.usefixtures("authorize_admin")
@pytest.mark.parametrize("mint", [True, False])
def test_multiple_mints_or_redeems(
    vault_safety_mode, admin, mint, chain, MockGyroVault, gyro_config
):
    value_index = 0 if mint else 1
    other_value_index = 1 if mint else 0
    query_check = (
        vault_safety_mode.isMintSafe if mint else vault_safety_mode.isRedeemSafe
    )
    execute_check = (
        vault_safety_mode.checkAndPersistMint
        if mint
        else vault_safety_mode.checkAndPersistRedeem
    )

    # mint/redeem with two vaults and ensure that everything is persisted correctly
    amount_a_1 = 2 * 10**18
    vault_info_a = _create_vault_info(admin, MockGyroVault, 18, 10**19)
    vault_info_b = _create_vault_info(admin, MockGyroVault, 6, 10**8)
    order = Order(
        mint=mint,
        vaults_with_amount=[
            VaultWithAmount(vault_info=vault_info_a, amount=amount_a_1),
            VaultWithAmount(vault_info=vault_info_b, amount=30 * 10**6),
        ],
    )
    assert query_check(order) == ""
    tx = execute_check(order)
    assert not tx.events
    persisted_a = vault_safety_mode.persistedFlowData(
        order.vaults_with_amount[0].vault_info.vault
    )
    assert persisted_a[value_index][0] == order.vaults_with_amount[0].amount
    assert persisted_a[value_index][1] == 0
    assert persisted_a[value_index][2] == tx.block_number
    assert persisted_a[other_value_index][0] == 0
    assert persisted_a[other_value_index][1] == 0
    assert persisted_a[other_value_index][2] == 0

    persisted_b = vault_safety_mode.persistedFlowData(
        order.vaults_with_amount[1].vault_info.vault
    )
    assert persisted_b[value_index][0] == order.vaults_with_amount[1].amount
    assert persisted_b[other_value_index][0] == 0

    order = Order(
        mint=mint,
        vaults_with_amount=[
            VaultWithAmount(vault_info=vault_info_a, amount=9 * 10**18)
        ],
    )
    assert query_check(order) == error_codes.VAULT_FLOW_TOO_HIGH
    with reverts(error_codes.VAULT_FLOW_TOO_HIGH):
        execute_check(order)

    amount_a_2 = 3 * 10**18
    order = Order(
        mint=mint,
        vaults_with_amount=[
            VaultWithAmount(vault_info=vault_info_a, amount=amount_a_2)
        ],
    )
    tx = execute_check(order)
    assert not tx.events
    persisted_a = vault_safety_mode.persistedFlowData(
        order.vaults_with_amount[0].vault_info.vault
    )
    # ensure that the updated flow makes sense and uses the discounted sum
    assert persisted_a[value_index][0] < amount_a_1 + amount_a_2

    # ensure that the safety mode is activated when required
    amount_a_3 = int(scale("4.5"))  # type: ignore
    order = Order(
        mint=mint,
        vaults_with_amount=[
            VaultWithAmount(vault_info=vault_info_a, amount=amount_a_3)
        ],
    )
    tx = execute_check(order)
    assert (
        tx.events["SafetyStatus"]["err"]
        == error_codes.OPERATION_SUCCEEDS_BUT_SAFETY_MODE_ACTIVATED
    )
    persisted_a = vault_safety_mode.persistedFlowData(
        order.vaults_with_amount[0].vault_info.vault
    )
    assert persisted_a[value_index][0] < amount_a_1 + amount_a_2 + amount_a_3
    assert persisted_a[value_index][1] == tx.block_number + gyro_config.getUint(
        config_keys.SAFETY_BLOCKS_AUTOMATIC
    )

    assert query_check(order) == error_codes.SAFETY_MODE_ACTIVATED
    # we cannot use the vault once the safety mode is activated
    with reverts(error_codes.SAFETY_MODE_ACTIVATED):
        execute_check(order)

    # but we can mint/redeem with other vaults
    order = Order(
        mint=mint,
        vaults_with_amount=[
            VaultWithAmount(vault_info=vault_info_b, amount=30 * 10**6),
        ],
    )
    tx = execute_check(order)
    assert not tx.events

    chain.mine(gyro_config.getUint(config_keys.SAFETY_BLOCKS_AUTOMATIC))

    # once the safety mode is deactivated (after n blocks), we can use the vault again
    order = Order(
        mint=mint,
        vaults_with_amount=[
            VaultWithAmount(vault_info=vault_info_a, amount=amount_a_3)
        ],
    )
    tx = execute_check(order)
    assert not tx.events


@pytest.mark.usefixtures("authorize_admin")
def test_mixed_mints_and_redeems(
    vault_safety_mode, admin, chain, MockGyroVault, gyro_config
):
    vault_info = _create_vault_info(admin, MockGyroVault, 18, 10**19)
    mint_order = Order(
        mint=True,
        vaults_with_amount=[
            VaultWithAmount(vault_info=vault_info, amount=7 * 10**18)
        ],
    )
    tx = vault_safety_mode.checkAndPersistMint(mint_order)
    assert not tx.events

    chain.mine(gyro_config.getUint(config_keys.SAFETY_BLOCKS_AUTOMATIC) * 10)

    redeem_order = Order(
        mint=False,
        vaults_with_amount=[
            VaultWithAmount(vault_info=vault_info, amount=7 * 10**18)
        ],
    )
    tx = vault_safety_mode.checkAndPersistRedeem(redeem_order)
    assert not tx.events

    tx = vault_safety_mode.checkAndPersistMint(mint_order)
    assert not tx.events

    with reverts(error_codes.VAULT_FLOW_TOO_HIGH):
        vault_safety_mode.checkAndPersistRedeem(redeem_order)


@pytest.mark.parametrize("mint", [True, False])
@pytest.mark.usefixtures("authorize_admin")
def test_guardian_oracle(vault_safety_mode, admin, chain, MockGyroVault, mint):
    tx = vault_safety_mode.addAddressToWhitelist(admin, {"from": admin})
    assert tx.events["AddedToWhitelist"]["account"] == admin

    vault_info_a = _create_vault_info(admin, MockGyroVault, 18, 10**19)
    vault_info_b = _create_vault_info(admin, MockGyroVault, 18, 10**19)

    direction = FlowDirection.IN if mint else FlowDirection.OUT
    guarded_check, normal_check = (
        vault_safety_mode.checkAndPersistMint,
        vault_safety_mode.checkAndPersistRedeem,
    )
    if not mint:
        guarded_check, normal_check = normal_check, guarded_check

    tx = vault_safety_mode.activateOracleGuardian((vault_info_a.vault, direction), 100)
    assert len(tx.events["OracleGuardianActivated"]) == 1
    assert tx.events["OracleGuardianActivated"]["vaultAddress"] == vault_info_a.vault
    assert tx.events["OracleGuardianActivated"]["durationOfProtectionInBlocks"] == 100
    assert tx.events["OracleGuardianActivated"]["inFlows"] == mint

    failing_order = Order(
        mint=mint,
        vaults_with_amount=[
            VaultWithAmount(vault_info=vault_info_a, amount=7 * 10**18)
        ],
    )
    with reverts(error_codes.SAFETY_MODE_ACTIVATED):
        guarded_check(failing_order)

    other_vault_order = Order(
        mint=mint,
        vaults_with_amount=[
            VaultWithAmount(vault_info=vault_info_b, amount=30 * 10**6)
        ],
    )
    tx = guarded_check(other_vault_order)
    assert not tx.events

    non_guarded_order = Order(
        mint=not mint,
        vaults_with_amount=[
            VaultWithAmount(vault_info=vault_info_a, amount=7 * 10**18)
        ],
    )
    tx = normal_check(non_guarded_order)
    assert not tx.events

    chain.mine(100)
    guarded_order = Order(
        mint=mint,
        vaults_with_amount=[
            VaultWithAmount(vault_info=vault_info_a, amount=7 * 10**18)
        ],
    )
    tx = guarded_check(guarded_order)
    assert not tx.events

    tx = vault_safety_mode.activateOracleGuardian(
        (vault_info_a.vault, FlowDirection.BOTH), 100
    )
    assert len(tx.events["OracleGuardianActivated"]) == 2
    assert tx.events["OracleGuardianActivated"][0]["vaultAddress"] == vault_info_a.vault
    assert (
        tx.events["OracleGuardianActivated"][0]["durationOfProtectionInBlocks"] == 100
    )
    assert tx.events["OracleGuardianActivated"]["inFlows"] == True
    assert tx.events["OracleGuardianActivated"][1]["vaultAddress"] == vault_info_a.vault
    assert (
        tx.events["OracleGuardianActivated"][1]["durationOfProtectionInBlocks"] == 100
    )
    assert tx.events["OracleGuardianActivated"][1]["inFlows"] == False

    mint_order = Order(
        mint=True,
        vaults_with_amount=[
            VaultWithAmount(vault_info=vault_info_a, amount=7 * 10**18)
        ],
    )
    redeem_order = Order(
        mint=False,
        vaults_with_amount=[
            VaultWithAmount(vault_info=vault_info_a, amount=7 * 10**18)
        ],
    )

    with reverts(error_codes.SAFETY_MODE_ACTIVATED):
        vault_safety_mode.checkAndPersistMint(mint_order)

    with reverts(error_codes.SAFETY_MODE_ACTIVATED):
        vault_safety_mode.checkAndPersistRedeem(redeem_order)

    chain.mine(100)

    tx = vault_safety_mode.checkAndPersistMint(mint_order)
    assert not tx.events

    tx = vault_safety_mode.checkAndPersistRedeem(redeem_order)
    assert not tx.events


@pytest.mark.parametrize("deposits_only", [True, False])
@pytest.mark.usefixtures("authorize_admin")
def test_pause_protocol(
    vault_safety_mode,
    static_percentage_fee_handler,
    admin,
    reserve_manager,
    MockGyroVault,
    deposits_only,
    mock_price_oracle,
    gyro_config,
):
    tx = vault_safety_mode.addAddressToWhitelist(admin, {"from": admin})
    vaults = []
    vault_configurations = []
    for _ in range(2):
        v = _create_vault_info(admin, MockGyroVault, 18, 10**19)
        mock_price_oracle.setUSDPrice(v.vault, scale(1), {"from": admin})
        static_percentage_fee_handler.setVaultFees(v.vault, 0, 0, {"from": admin})
        vault_configurations.append(VaultConfiguration(v.vault, v.persisted_metadata))
        vaults.append(v)
    reserve_manager.setVaults(vault_configurations, {"from": admin})

    tx = vault_safety_mode.pauseProtocol(deposits_only, {"from": admin})
    if deposits_only:
        assert len(tx.events["OracleGuardianActivated"]) == len(vaults)
    else:
        assert len(tx.events["OracleGuardianActivated"]) == len(vaults) * 2
    assert tx.events["OracleGuardianActivated"][0][
        "durationOfProtectionInBlocks"
    ] == gyro_config.getUint(config_keys.SAFETY_BLOCKS_GUARDIAN)

    for vault in vaults:
        mint_order = Order(
            mint=True,
            vaults_with_amount=[VaultWithAmount(vault_info=vault, amount=7 * 10**18)],
        )
        redeem_order = Order(
            mint=False,
            vaults_with_amount=[VaultWithAmount(vault_info=vault, amount=7 * 10**18)],
        )

        with reverts(error_codes.SAFETY_MODE_ACTIVATED):
            vault_safety_mode.checkAndPersistMint(mint_order)

        if deposits_only:
            tx = vault_safety_mode.checkAndPersistRedeem(redeem_order)
            assert not tx.events
        else:
            with reverts(error_codes.SAFETY_MODE_ACTIVATED):
                vault_safety_mode.checkAndPersistRedeem(redeem_order)
