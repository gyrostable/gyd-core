from typing import Optional
import hypothesis.strategies as st
from brownie import accounts
from brownie.test import given
from hypothesis import settings

from tests.reserve import object_creation
from tests.reserve.reserve_math_implementation import (
    build_metadata,
    calculate_target_weights,
    calculate_weights_and_total,
    is_mint_safe,
    is_redeem_safe,
    safe_to_execute_outside_epsilon,
    update_metadata_with_epsilon_status,
    update_metadata_with_price_safety,
    update_vault_with_price_safety,
    vault_weight_off_peg_falls,
)
from tests.support import constants, error_codes
from tests.support.quantized_decimal import DecimalLike, QuantizedDecimal as D
from tests.support.types import (
    Order,
    PersistedVaultMetadata,
    PricedToken,
    VaultInfo,
    VaultWithAmount,
)
from tests.support.utils import scale, to_decimal

amount_generator = st.integers(
    min_value=int(scale("0.001")), max_value=int(scale(1_000_000_000))
)
price_generator = st.integers(
    min_value=int(scale("0.001")), max_value=int(scale(1_000_000_000))
)
weight_generator = st.integers(min_value=int(scale("0.001")), max_value=int(scale(1)))

boolean_generator = st.booleans()

stablecoin_price_generator = st.integers(
    min_value=int(scale("0.94")), max_value=int(scale("1.06"))
)

vault_metadatas = st.tuples(
    weight_generator,
    weight_generator,
    weight_generator,
    price_generator,
    boolean_generator,
    boolean_generator,
    boolean_generator,
)


global_metadatas = st.tuples(
    boolean_generator, boolean_generator, boolean_generator, boolean_generator
)


def _create_vault_info(
    reserve_balance: DecimalLike,
    price: DecimalLike,
    current_weight: DecimalLike,
    is_stable: bool = False,
    decimals: int = 18,
    target_weight: Optional[DecimalLike] = None,
    initial_weight: Optional[DecimalLike] = None,
    initial_price: Optional[DecimalLike] = None,
):
    if target_weight is None:
        target_weight = current_weight
    if initial_weight is None:
        initial_weight = current_weight
    if initial_price is None:
        initial_price = price

    underlying_address = accounts.add().address

    return VaultInfo(
        vault=accounts.add().address,
        decimals=decimals,
        current_weight=int(scale(current_weight)),
        target_weight=int(scale(target_weight)),
        persisted_metadata=PersistedVaultMetadata(
            price_at_calibration=int(scale(initial_price)),
            weight_at_calibration=int(scale(initial_weight)),
            short_flow_memory=int(constants.OUTFLOW_MEMORY),
            short_flow_threshold=int(scale(1_000_000)),
        ),
        price=int(scale(price)),
        priced_tokens=[
            PricedToken(
                tokenAddress=underlying_address,
                price=int(scale(price)),
                is_stable=is_stable,
            )
        ],
        reserve_balance=int(scale(reserve_balance, decimals)),
        underlying=underlying_address,
    )


def test_balanced_deposit(reserve_safety_manager):
    vault_dai = _create_vault_info(1200, 1, "0.5", is_stable=True)
    vault_eth = _create_vault_info(1, 1200, "0.5")
    order = Order(
        mint=True,
        vaults_with_amount=[
            VaultWithAmount(vault_info=vault_dai, amount=int(scale(1200))),
            VaultWithAmount(vault_info=vault_eth, amount=int(scale(1))),
        ],
    )
    assert reserve_safety_manager.isMintSafe(order) == ""


def test_balanced_deposit_with_different_decimals(reserve_safety_manager):
    vault_dai = _create_vault_info(2400, 1, "0.5", is_stable=True)
    vault_eth = _create_vault_info(1, 1200, "0.25")
    vault_usdc = _create_vault_info(1200, 1, "0.25", is_stable=True, decimals=6)
    order = Order(
        mint=True,
        vaults_with_amount=[
            VaultWithAmount(vault_info=vault_dai, amount=int(scale(2400))),
            VaultWithAmount(vault_info=vault_eth, amount=int(scale(1))),
            VaultWithAmount(vault_info=vault_usdc, amount=int(scale(1200, 6))),
        ],
    )
    assert reserve_safety_manager.isMintSafe(order) == ""


def test_deposit_within_epsilon(reserve_safety_manager):
    vault_dai = _create_vault_info(2400, 1, "0.5", is_stable=True)
    vault_eth = _create_vault_info(1, 1200, "0.25")
    vault_usdc = _create_vault_info(1200, 1, "0.25", is_stable=True, decimals=6)
    order = Order(
        mint=True,
        vaults_with_amount=[
            VaultWithAmount(vault_info=vault_dai, amount=int(scale(2300))),
            VaultWithAmount(vault_info=vault_eth, amount=int(scale(1))),
            VaultWithAmount(vault_info=vault_usdc, amount=int(scale(1100, 6))),
        ],
    )
    assert reserve_safety_manager.isMintSafe(order) == ""


def test_deposit_outside_epsilon(reserve_safety_manager):
    vault_dai = _create_vault_info(2400, 1, "0.5", is_stable=True)
    vault_eth = _create_vault_info(1, 1200, "0.25")
    vault_usdc = _create_vault_info(1200, 1, "0.25", is_stable=True, decimals=6)
    order = Order(
        mint=True,
        vaults_with_amount=[
            VaultWithAmount(vault_info=vault_dai, amount=int(scale(3000))),
            VaultWithAmount(vault_info=vault_eth, amount=int(scale(1))),
            VaultWithAmount(vault_info=vault_usdc, amount=int(scale(500, 6))),
        ],
    )
    assert reserve_safety_manager.isMintSafe(order) == error_codes.NOT_SAFE_TO_MINT


def test_balanced_withdraw(reserve_safety_manager):
    vault_dai = _create_vault_info(1200, 1, "0.5", is_stable=True)
    vault_eth = _create_vault_info(1, 1200, "0.5")
    order = Order(
        mint=False,
        vaults_with_amount=[
            VaultWithAmount(vault_info=vault_dai, amount=int(scale(600))),
            VaultWithAmount(vault_info=vault_eth, amount=int(scale("0.5"))),
        ],
    )
    assert reserve_safety_manager.isRedeemSafe(order) == ""


def test_balanced_withdraw_with_different_decimals(reserve_safety_manager):
    vault_dai = _create_vault_info(2400, 1, "0.5", is_stable=True)
    vault_eth = _create_vault_info(1, 1200, "0.25")
    vault_usdc = _create_vault_info(1200, 1, "0.25", is_stable=True, decimals=6)
    order = Order(
        mint=False,
        vaults_with_amount=[
            VaultWithAmount(vault_info=vault_dai, amount=int(scale(1200))),
            VaultWithAmount(vault_info=vault_eth, amount=int(scale("0.5"))),
            VaultWithAmount(vault_info=vault_usdc, amount=int(scale(600, 6))),
        ],
    )
    assert reserve_safety_manager.isRedeemSafe(order) == ""


def test_withdraw_within_epsilon(reserve_safety_manager):
    vault_dai = _create_vault_info(2400, 1, "0.5", is_stable=True)
    vault_eth = _create_vault_info(1, 1200, "0.25")
    vault_usdc = _create_vault_info(1200, 1, "0.25", is_stable=True, decimals=6)
    order = Order(
        mint=False,
        vaults_with_amount=[
            VaultWithAmount(vault_info=vault_dai, amount=int(scale(1180))),
            VaultWithAmount(vault_info=vault_eth, amount=int(scale("0.5"))),
            VaultWithAmount(vault_info=vault_usdc, amount=int(scale(620, 6))),
        ],
    )
    assert reserve_safety_manager.isRedeemSafe(order) == ""


def test_withdraw_outside_epsilon(reserve_safety_manager):
    vault_dai = _create_vault_info(2400, 1, "0.5", is_stable=True)
    vault_eth = _create_vault_info(1, 1200, "0.25")
    vault_usdc = _create_vault_info(1200, 1, "0.25", is_stable=True, decimals=6)
    order = Order(
        mint=False,
        vaults_with_amount=[
            VaultWithAmount(vault_info=vault_dai, amount=int(scale(1000))),
            VaultWithAmount(vault_info=vault_eth, amount=int(scale("0.5"))),
            VaultWithAmount(vault_info=vault_usdc, amount=int(scale(500, 6))),
        ],
    )
    assert reserve_safety_manager.isRedeemSafe(order) == error_codes.NOT_SAFE_TO_REDEEM


@given(
    amounts_and_prices=st.lists(
        st.tuples(amount_generator, price_generator), min_size=1
    )
)
@settings(max_examples=10)
def test_calculate_weights_and_total(reserve_safety_manager, amounts_and_prices):
    amounts, prices = [list(v) for v in zip(*amounts_and_prices)]

    weights_exp, total_exp = calculate_weights_and_total(
        to_decimal(amounts), to_decimal(prices)
    )
    weights_sol, total_sol = reserve_safety_manager.calculateWeightsAndTotal(
        amounts, prices
    )

    approxed_expected_weights = [scale(i).approxed() for i in weights_exp]

    assert to_decimal(weights_sol) == approxed_expected_weights
    assert total_exp == scale(total_sol).approxed()


@given(
    bundle_metadata=st.tuples(
        object_creation.vault_lists(vault_metadatas), global_metadatas
    )
)
def test_check_any_off_peg_vault_would_move_closer_to_target_weight(
    reserve_safety_manager, bundle_metadata, mock_vaults, mock_price_oracle
):
    metadata = object_creation.bundle_to_metadata(
        bundle_metadata, mock_vaults, mock_price_oracle
    )

    result_sol = reserve_safety_manager.vaultWeightWithOffPegFalls(metadata)
    result_exp = vault_weight_off_peg_falls(metadata)

    assert result_sol == result_exp


@given(
    order_bundle=st.lists(
        st.tuples(
            price_generator,
            weight_generator,
            amount_generator,
            price_generator,
            amount_generator,
            weight_generator,
            weight_generator,
        ),
        min_size=1,
        max_size=10,
    )
)
@settings(max_examples=10)
def test_build_metadata(
    reserve_safety_manager, order_bundle, mock_vaults, mock_price_oracle
):
    mint_order = object_creation.bundle_to_order(
        order_bundle, True, mock_vaults, mock_price_oracle
    )

    metadata_sol = reserve_safety_manager.buildMetaData(mint_order)
    metadata_exp = build_metadata(mint_order, mock_vaults)

    assert metadata_sol[1] == metadata_exp[1]
    assert metadata_sol[2] == metadata_exp[2]
    assert metadata_sol[3] == metadata_exp[3]
    assert metadata_sol[4] == metadata_exp[4]

    vault_metadata_array_sol = metadata_sol[0]
    vault_metadata_array_exp = metadata_exp[0]

    for i in range(len(mint_order[0])):
        assert vault_metadata_array_sol[i][0] == vault_metadata_array_exp[i][0]
        assert vault_metadata_array_sol[i][1] == vault_metadata_array_exp[i][1]
        assert vault_metadata_array_sol[i][2] == vault_metadata_array_exp[i][2]
        # assert (
        #     D(vault_metadata_array_sol[i][3])
        #     == scale(vault_metadata_array_exp[i][3].approxed()
        # )
        assert vault_metadata_array_sol[i][4] == vault_metadata_array_exp[i][4]
        assert vault_metadata_array_sol[i][5] == vault_metadata_array_exp[i][5]
        assert vault_metadata_array_sol[i][6] == vault_metadata_array_exp[i][6]
        assert vault_metadata_array_sol[i][7] == vault_metadata_array_exp[i][7]


@given(
    bundle_metadata=st.tuples(
        object_creation.vault_lists(vault_metadatas), global_metadatas
    )
)
def test_update_metadata_with_epsilon_status(
    reserve_safety_manager, bundle_metadata, mock_vaults, mock_price_oracle
):
    metadata = object_creation.bundle_to_metadata(
        bundle_metadata, mock_vaults, mock_price_oracle
    )

    result_sol = reserve_safety_manager.updateMetaDataWithEpsilonStatus(metadata)
    result_exp = update_metadata_with_epsilon_status(metadata)

    assert result_sol[1] == result_exp[1]


@given(bundle_vault_metadata=vault_metadatas)
def test_update_vault_with_price_safety(
    reserve_safety_manager,
    bundle_vault_metadata,
    mock_price_oracle,
    dai,
    usdc,
    asset_registry,
    admin,
    mock_vaults,
):
    asset_registry.setAssetAddress("DAI", dai)
    asset_registry.addStableAsset(dai, {"from": admin})

    asset_registry.setAssetAddress("USDC", usdc)
    asset_registry.addStableAsset(usdc, {"from": admin})

    mock_vaults[0].setTokens([usdc, dai])

    mock_price_oracle.setUSDPrice(dai, D("1e18"))
    mock_price_oracle.setUSDPrice(usdc, D("1e18"))

    ([vault_metadata], _) = object_creation.bundle_to_metadata(
        ([bundle_vault_metadata], (None,)),
        mock_vaults,
        mock_price_oracle,
        token_stables=[True, True],
    )

    vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
        vault_metadata
    )

    status_of_all_stablecoins = vault_metadata_sol[5]
    assert status_of_all_stablecoins == True

    mock_price_oracle.setUSDPrice(dai, D("0.8e18"))

    ([vault_metadata], _) = object_creation.bundle_to_metadata(
        ([bundle_vault_metadata], (None,)),
        mock_vaults,
        mock_price_oracle,
        token_stables=[True, True],
    )

    vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
        vault_metadata
    )
    status_of_all_stablecoins = vault_metadata_sol[5]
    assert status_of_all_stablecoins == False

    mock_price_oracle.setUSDPrice(dai, D("0.95e18"))

    ([vault_metadata], _) = object_creation.bundle_to_metadata(
        ([bundle_vault_metadata], (None,)),
        mock_vaults,
        mock_price_oracle,
        token_stables=[True, True],
    )

    vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
        vault_metadata
    )
    status_of_all_stablecoins = vault_metadata_sol[5]
    assert status_of_all_stablecoins == True

    mock_price_oracle.setUSDPrice(dai, D("0.94e18"))

    ([vault_metadata], _) = object_creation.bundle_to_metadata(
        ([bundle_vault_metadata], (None,)),
        mock_vaults,
        mock_price_oracle,
        token_stables=[True, True],
    )

    vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
        vault_metadata
    )
    status_of_all_stablecoins = vault_metadata_sol[5]
    assert status_of_all_stablecoins == False


@given(bundle_vault_metadata=vault_metadatas)
def test_update_vault_with_price_safety_tiny_prices(
    reserve_safety_manager,
    bundle_vault_metadata,
    mock_price_oracle,
    abc,
    sdt,
    asset_registry,
    mock_vaults,
):
    asset_registry.setAssetAddress("ABC", abc)
    asset_registry.setAssetAddress("SDT", sdt)
    mock_vaults[0].setTokens([sdt, abc])

    mock_price_oracle.setUSDPrice(abc, D("1e16"))
    mock_price_oracle.setUSDPrice(sdt, D("1e16"))

    ([vault_metadata], _) = object_creation.bundle_to_metadata(
        ([bundle_vault_metadata], (None,)), mock_vaults, mock_price_oracle
    )

    vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
        vault_metadata
    )

    prices_large_enough = vault_metadata_sol[6]
    assert prices_large_enough == True

    mock_price_oracle.setUSDPrice(abc, D("1e12"))
    mock_price_oracle.setUSDPrice(sdt, D("1e12"))

    ([vault_metadata], _) = object_creation.bundle_to_metadata(
        ([bundle_vault_metadata], (None,)), mock_vaults, mock_price_oracle
    )
    vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
        vault_metadata
    )

    prices_large_enough = vault_metadata_sol[6]
    assert prices_large_enough == False

    mock_price_oracle.setUSDPrice(abc, D("1e13"))
    mock_price_oracle.setUSDPrice(sdt, D("1e13"))

    ([vault_metadata], _) = object_creation.bundle_to_metadata(
        ([bundle_vault_metadata], (None,)), mock_vaults, mock_price_oracle
    )
    vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
        vault_metadata
    )

    prices_large_enough = vault_metadata_sol[6]
    assert prices_large_enough == True

    mock_price_oracle.setUSDPrice(abc, D("0.95e12"))
    mock_price_oracle.setUSDPrice(sdt, D("1e13"))

    ([vault_metadata], _) = object_creation.bundle_to_metadata(
        ([bundle_vault_metadata], (None,)), mock_vaults, mock_price_oracle
    )
    vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
        vault_metadata
    )

    prices_large_enough = vault_metadata_sol[6]
    assert prices_large_enough == True

    mock_price_oracle.setUSDPrice(abc, D("0.95e12"))
    mock_price_oracle.setUSDPrice(sdt, D("0.95e12"))
    ([vault_metadata], _) = object_creation.bundle_to_metadata(
        ([bundle_vault_metadata], (None,)), mock_vaults, mock_price_oracle
    )
    vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
        vault_metadata
    )

    prices_large_enough = vault_metadata_sol[6]
    assert prices_large_enough == False


@given(
    bundle_metadata=st.tuples(
        object_creation.vault_lists(vault_metadatas), global_metadatas
    )
)
def test_update_metadata_with_price_safety_peg(
    bundle_metadata,
    reserve_safety_manager,
    asset_registry,
    dai,
    usdc,
    admin,
    mock_price_oracle,
    mock_vaults,
):
    mock_vaults[0].setTokens([usdc, dai])
    mock_price_oracle.setUSDPrice(dai, D("1e18"))
    mock_price_oracle.setUSDPrice(usdc, D("1e18"))

    metadata = object_creation.bundle_to_metadata(
        bundle_metadata, mock_vaults, mock_price_oracle
    )

    asset_registry.setAssetAddress("DAI", dai)
    asset_registry.addStableAsset(dai, {"from": admin})

    asset_registry.setAssetAddress("USDC", usdc)
    asset_registry.addStableAsset(usdc, {"from": admin})

    updated_metadata = reserve_safety_manager.updateMetadataWithPriceSafety(metadata)
    onenotonpeg = False
    for vault in updated_metadata[0]:
        if vault[5] == False:
            onenotonpeg = True

    if onenotonpeg:
        assert updated_metadata[2] == False
    else:
        assert updated_metadata[2] == True

    mock_price_oracle.setUSDPrice(usdc, D("0.92e18"))

    metadata = object_creation.bundle_to_metadata(
        bundle_metadata, mock_vaults, mock_price_oracle
    )

    updated_metadata = reserve_safety_manager.updateMetadataWithPriceSafety(metadata)
    onenotonpeg = False
    for vault in updated_metadata[0]:
        if vault[5] == False:
            onenotonpeg = True

    if onenotonpeg:
        assert updated_metadata[2] == False
    else:
        assert updated_metadata[2] == True


@given(
    bundle_metadata=st.tuples(
        object_creation.vault_lists(vault_metadatas), global_metadatas
    )
)
def test_update_metadata_with_price_safety_tiny_prices(
    bundle_metadata,
    reserve_safety_manager,
    abc,
    sdt,
    asset_registry,
    mock_price_oracle,
    mock_vaults,
):
    mock_price_oracle.setUSDPrice(abc, D("1e16"))
    mock_price_oracle.setUSDPrice(sdt, D("1e16"))

    mock_vaults[0].setTokens([abc, sdt])

    metadata = object_creation.bundle_to_metadata(
        bundle_metadata, mock_vaults, mock_price_oracle
    )

    asset_registry.setAssetAddress("ABC", abc)
    asset_registry.setAssetAddress("SDT", sdt)

    updated_metadata = reserve_safety_manager.updateMetadataWithPriceSafety(metadata)
    onevaultpricestoosmall = False
    for vault in updated_metadata[0]:
        if vault[6] == False:
            onevaultpricestoosmall = True

    if onevaultpricestoosmall:
        assert updated_metadata[3] == False
    else:
        assert updated_metadata[3] == True

    mock_price_oracle.setUSDPrice(sdt, D("1e12"))
    mock_price_oracle.setUSDPrice(abc, D("1e12"))

    metadata = object_creation.bundle_to_metadata(
        bundle_metadata, mock_vaults, mock_price_oracle
    )

    updated_metadata = reserve_safety_manager.updateMetadataWithPriceSafety(metadata)
    onevaultpricestoosmall = False
    for vault in updated_metadata[0]:
        if vault[6] == False:
            onevaultpricestoosmall = True

    if onevaultpricestoosmall:
        assert updated_metadata[3] == False
    else:
        assert updated_metadata[3] == True


@given(
    bundle_metadata=st.tuples(
        object_creation.vault_lists(vault_metadatas), global_metadatas
    )
)
def test_safe_to_execute_outside_epsilon(
    bundle_metadata, reserve_safety_manager, mock_vaults, mock_price_oracle
):
    metadata = object_creation.bundle_to_metadata(
        bundle_metadata, mock_vaults, mock_price_oracle
    )

    result_exp = safe_to_execute_outside_epsilon(metadata)

    result_sol = reserve_safety_manager.safeToExecuteOutsideEpsilon(metadata)

    assert result_exp == result_sol


@given(
    order_bundle=st.lists(
        st.tuples(
            price_generator,
            weight_generator,
            amount_generator,
            price_generator,
            amount_generator,
            weight_generator,
            weight_generator,
        ),
        min_size=5,
        max_size=5,
    )
)
def test_is_mint_safe_normal(
    reserve_safety_manager,
    order_bundle,
    asset_registry,
    admin,
    dai,
    usdc,
    sdt,
    abc,
    mock_price_oracle,
    mock_vaults,
):
    tokens = [[usdc, dai], [usdc, sdt], [sdt, dai], [abc, dai], [usdc, abc]]

    for i, token in enumerate(tokens):
        mock_vaults[i].setTokens(token)

    mock_price_oracle.setUSDPrice(dai, D("1e18"))
    mock_price_oracle.setUSDPrice(usdc, D("1e18"))
    mock_price_oracle.setUSDPrice(abc, D("1e18"))
    mock_price_oracle.setUSDPrice(sdt, D("1e18"))

    mint_order = object_creation.bundle_to_order(
        order_bundle, True, mock_vaults, mock_price_oracle
    )

    asset_registry.setAssetAddress("DAI", dai)
    asset_registry.addStableAsset(dai, {"from": admin})

    asset_registry.setAssetAddress("USDC", usdc)
    asset_registry.addStableAsset(usdc, {"from": admin})

    asset_registry.setAssetAddress("ABC", abc)
    asset_registry.addStableAsset(abc, {"from": admin})

    asset_registry.setAssetAddress("SDT", sdt)

    response = reserve_safety_manager.isMintSafe(mint_order)

    response_expected = is_mint_safe(
        mint_order, tokens, mock_price_oracle, asset_registry
    )

    assert response == response_expected


@given(
    order_bundle=st.lists(
        st.tuples(
            price_generator,
            weight_generator,
            amount_generator,
            price_generator,
            amount_generator,
            weight_generator,
            weight_generator,
        ),
        min_size=1,
        max_size=2,
    )
)
def test_is_mint_safe_small_prices(
    reserve_safety_manager,
    order_bundle,
    asset_registry,
    admin,
    dai,
    usdc,
    sdt,
    abc,
    mock_price_oracle,
    mock_vaults,
):
    tokens = [[abc, sdt], [dai, usdc]]

    for i, token in enumerate(tokens):
        mock_vaults[i].setTokens(token)

    mock_price_oracle.setUSDPrice(abc, D("1e11"))
    mock_price_oracle.setUSDPrice(sdt, D("1e11"))
    mock_price_oracle.setUSDPrice(dai, D("1e18"))
    mock_price_oracle.setUSDPrice(usdc, D("1e18"))

    mint_order = object_creation.bundle_to_order(
        order_bundle, True, mock_vaults, mock_price_oracle
    )

    asset_registry.setAssetAddress("ABC", abc)

    asset_registry.setAssetAddress("SDT", sdt)

    asset_registry.setAssetAddress("DAI", dai)
    asset_registry.addStableAsset(dai, {"from": admin})

    asset_registry.setAssetAddress("USDC", usdc)
    asset_registry.addStableAsset(usdc, {"from": admin})

    response = reserve_safety_manager.isMintSafe(mint_order)

    response_expected = is_mint_safe(
        mint_order, tokens, mock_price_oracle, asset_registry
    )

    assert response == response_expected == "55"


@given(
    order_bundle=st.lists(
        st.tuples(
            price_generator,
            weight_generator,
            amount_generator,
            price_generator,
            amount_generator,
            weight_generator,
            weight_generator,
        ),
        min_size=5,
        max_size=5,
    )
)
def test_is_mint_safe_off_peg(
    reserve_safety_manager,
    order_bundle,
    asset_registry,
    admin,
    dai,
    usdc,
    sdt,
    abc,
    mock_price_oracle,
    mock_vaults,
):
    tokens = [[usdc, dai], [usdc, sdt], [sdt, dai], [abc, dai], [usdc, abc]]

    for i, token in enumerate(tokens):
        mock_vaults[i].setTokens(token)

    mock_price_oracle.setUSDPrice(dai, D("0.8e18"))
    mock_price_oracle.setUSDPrice(usdc, D("1e18"))
    mock_price_oracle.setUSDPrice(abc, D("1e18"))
    mock_price_oracle.setUSDPrice(sdt, D("1e18"))

    stable_asets = [True, True, True, False]

    mint_order = object_creation.bundle_to_order(
        order_bundle, True, mock_vaults, mock_price_oracle, stable_assets=stable_asets
    )

    asset_registry.setAssetAddress("DAI", dai)
    asset_registry.addStableAsset(dai, {"from": admin})

    asset_registry.setAssetAddress("USDC", usdc)
    asset_registry.addStableAsset(usdc, {"from": admin})

    asset_registry.setAssetAddress("ABC", abc)
    asset_registry.addStableAsset(abc, {"from": admin})

    asset_registry.setAssetAddress("SDT", sdt)

    response = reserve_safety_manager.isMintSafe(mint_order)

    response_expected = is_mint_safe(
        mint_order, tokens, mock_price_oracle, asset_registry
    )

    assert response == response_expected


@given(
    order_bundle=st.lists(
        st.tuples(
            price_generator,
            weight_generator,
            amount_generator,
            price_generator,
            amount_generator,
            weight_generator,
            weight_generator,
        ),
        min_size=5,
        max_size=5,
    )
)
def test_is_redeem_safe_normal(
    reserve_safety_manager,
    asset_registry,
    admin,
    dai,
    usdc,
    sdt,
    abc,
    mock_price_oracle,
    mock_vaults,
    order_bundle,
):
    tokens = [[usdc, dai], [usdc, sdt], [sdt, dai], [abc, dai], [usdc, abc]]
    for i, token in enumerate(tokens):
        mock_vaults[i].setTokens(token)

    mock_price_oracle.setUSDPrice(dai, D("1e18"))
    mock_price_oracle.setUSDPrice(usdc, D("1e18"))
    mock_price_oracle.setUSDPrice(abc, D("1e18"))
    mock_price_oracle.setUSDPrice(sdt, D("1e18"))

    redeem_order = object_creation.bundle_to_order(
        order_bundle, False, mock_vaults, mock_price_oracle
    )

    asset_registry.setAssetAddress("DAI", dai)
    asset_registry.addStableAsset(dai, {"from": admin})

    asset_registry.setAssetAddress("USDC", usdc)
    asset_registry.addStableAsset(usdc, {"from": admin})

    asset_registry.setAssetAddress("ABC", abc)
    asset_registry.addStableAsset(abc, {"from": admin})

    asset_registry.setAssetAddress("SDT", sdt)

    response = reserve_safety_manager.isRedeemSafe(redeem_order)

    response_expected = is_redeem_safe(
        redeem_order, tokens, mock_price_oracle, asset_registry
    )

    assert response == response_expected


@given(
    order_bundle=st.lists(
        st.tuples(
            price_generator,
            weight_generator,
            amount_generator,
            price_generator,
            amount_generator,
            weight_generator,
            weight_generator,
        ),
        min_size=2,
        max_size=2,
    )
)
def test_is_redeem_safe_small_prices(
    reserve_safety_manager,
    order_bundle,
    asset_registry,
    admin,
    dai,
    usdc,
    sdt,
    abc,
    mock_price_oracle,
    mock_vaults,
):
    tokens = [[sdt, abc], [usdc, abc]]

    for i, token in enumerate(tokens):
        mock_vaults[i].setTokens(token)

    mock_price_oracle.setUSDPrice(abc, D("1e11"))
    mock_price_oracle.setUSDPrice(sdt, D("1e11"))
    mock_price_oracle.setUSDPrice(dai, D("1e18"))
    mock_price_oracle.setUSDPrice(usdc, D("1e18"))

    redeem_order = object_creation.bundle_to_order(
        order_bundle, False, mock_vaults, mock_price_oracle
    )

    asset_registry.setAssetAddress("ABC", abc)

    asset_registry.setAssetAddress("SDT", sdt)

    asset_registry.setAssetAddress("DAI", dai)
    asset_registry.addStableAsset(dai, {"from": admin})

    asset_registry.setAssetAddress("USDC", usdc)
    asset_registry.addStableAsset(usdc, {"from": admin})

    response = reserve_safety_manager.isRedeemSafe(redeem_order)

    response_expected = is_redeem_safe(
        redeem_order, tokens, mock_price_oracle, asset_registry
    )

    if not response == "56" == response_expected:
        assert response == response_expected == "55"
