import hypothesis.strategies as st
import pytest
from brownie.test import given

from tests.reserve.reserve_math_implementation import (
    calculate_ideal_weights,
    calculate_weights_and_total,
    update_metadata_with_epsilon_status,
    vault_weight_off_peg_falls,
)
from tests.support.quantized_decimal import QuantizedDecimal as D
from tests.support.utils import scale, to_decimal

MAX_VAULTS = 10


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
    weight_generator,
    price_generator,
    boolean_generator,
    boolean_generator,
    boolean_generator,
)

global_metadatas = st.tuples(
    boolean_generator, boolean_generator, boolean_generator, boolean_generator
)


def vault_lists(*args, **kwargs):
    return st.lists(*args, **kwargs, min_size=1, max_size=MAX_VAULTS)


def vault_builder(price_generator, amount_generator, weight_generator):
    persisted_metadata = (price_generator, weight_generator)
    vault_info = (
        "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
        price_generator,
        persisted_metadata,
        amount_generator,
        weight_generator,
    )
    return (vault_info, amount_generator)


def bundle_to_metadata(bundle, mock_vaults):
    vaults_metadata, global_metadata = bundle
    vaults_metadata = [(mock_vaults[i],) + v for i, v in enumerate(vaults_metadata)]
    return (vaults_metadata,) + global_metadata


def bundle_to_vaults(bundle):
    prices, amounts, weights = [list(v) for v in zip(*bundle)]

    vaults_with_amount = []
    for i in range(len(prices)):
        vault = vault_builder(prices[i], amounts[i], weights[i])
        vaults_with_amount.append(vault)

    return vaults_with_amount


@pytest.fixture(scope="module")
def mock_vaults(admin, MockGyroVault, dai):
    return [admin.deploy(MockGyroVault, dai) for _ in range(MAX_VAULTS)]


@given(
    amounts_and_prices=st.lists(
        st.tuples(amount_generator, price_generator), min_size=1
    )
)
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
    bundle=st.lists(
        st.tuples(price_generator, amount_generator, weight_generator), min_size=1
    )
)
def test_calculate_ideal_weights(reserve_safety_manager, bundle):
    vaults_with_amount = bundle_to_vaults(bundle)

    result_exp = calculate_ideal_weights(vaults_with_amount)

    result_sol = reserve_safety_manager.calculateIdealWeights(vaults_with_amount)

    assert scale(result_exp) == to_decimal(result_sol)


@given(bundle_metadata=st.tuples(vault_lists(vault_metadatas), global_metadatas))
def test_check_any_off_peg_vault_would_move_closer_to_ideal_weight(
    reserve_safety_manager, bundle_metadata, mock_vaults
):
    metadata = bundle_to_metadata(bundle_metadata, mock_vaults)

    result_sol = reserve_safety_manager.vaultWeightWithOffPegFalls(metadata)
    result_exp = vault_weight_off_peg_falls(metadata)

    assert result_sol == result_exp


# @given(bundle=st.lists(st.tuples(price_generator, amount_generator, weight_generator)))
# def test_build_metadata(reserve_safety_manager, bundle):
#     if not bundle:
#         return
#     vaults_with_amount = bundle_to_vaults(bundle)
#     metadata_exp = build_metadata(vaults_with_amount)

#     metadata_sol = reserve_safety_manager.buildMetaData(vaults_with_amount)

#     print("SOL", metadata_sol)
#     print("EXP", metadata_exp)


@given(bundle_metadata=st.tuples(vault_lists(vault_metadatas), global_metadatas))
def test_update_metadata_with_epsilon_status(
    reserve_safety_manager, bundle_metadata, mock_vaults
):
    metadata = bundle_to_metadata(bundle_metadata, mock_vaults)

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

    vault_metadata = (mock_vaults[0],) + bundle_vault_metadata

    mock_vaults[0].setTokens([usdc, dai])

    mock_price_oracle.setUSDPrice(dai, D("1e18"))
    mock_price_oracle.setUSDPrice(usdc, D("1e18"))
    vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
        vault_metadata
    )

    status_of_all_stablecoins = vault_metadata_sol[6]
    assert status_of_all_stablecoins == True

    mock_price_oracle.setUSDPrice(dai, D("0.8e18"))

    vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
        vault_metadata
    )
    status_of_all_stablecoins = vault_metadata_sol[6]
    assert status_of_all_stablecoins == False

    mock_price_oracle.setUSDPrice(dai, D("0.95e18"))

    vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
        vault_metadata
    )
    status_of_all_stablecoins = vault_metadata_sol[6]
    assert status_of_all_stablecoins == True

    mock_price_oracle.setUSDPrice(dai, D("0.94e18"))

    vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
        vault_metadata
    )
    status_of_all_stablecoins = vault_metadata_sol[6]
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

    vault_metadata = (mock_vaults[0],) + bundle_vault_metadata
    mock_vaults[0].setTokens([sdt, abc])

    mock_price_oracle.setUSDPrice(abc, D("1e16"))
    mock_price_oracle.setUSDPrice(sdt, D("1e16"))
    vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
        vault_metadata
    )

    prices_large_enough = vault_metadata_sol[7]
    assert prices_large_enough == True

    mock_price_oracle.setUSDPrice(abc, D("1e12"))
    mock_price_oracle.setUSDPrice(sdt, D("1e12"))
    vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
        vault_metadata
    )

    prices_large_enough = vault_metadata_sol[7]
    assert prices_large_enough == False

    mock_price_oracle.setUSDPrice(abc, D("1e13"))
    mock_price_oracle.setUSDPrice(sdt, D("1e13"))
    vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
        vault_metadata
    )

    prices_large_enough = vault_metadata_sol[7]
    assert prices_large_enough == True

    mock_price_oracle.setUSDPrice(abc, D("0.95e12"))
    mock_price_oracle.setUSDPrice(sdt, D("1e13"))
    vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
        vault_metadata
    )

    prices_large_enough = vault_metadata_sol[7]
    assert prices_large_enough == True

    mock_price_oracle.setUSDPrice(abc, D("0.95e12"))
    mock_price_oracle.setUSDPrice(sdt, D("0.95e12"))
    vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
        vault_metadata
    )

    prices_large_enough = vault_metadata_sol[7]
    assert prices_large_enough == False


@given(bundle_metadata=st.tuples(vault_lists(vault_metadatas), global_metadatas))
def test_update_metadata_with_price_safety(bundle_metadata, mock_vaults):
    metadata = bundle_to_metadata(bundle_metadata, mock_vaults)
    print(metadata)


def test_safe_to_execute_outside_epsilon():
    pass


def test_is_mint_safe():
    pass


def test_is_redeem_safe():
    pass
