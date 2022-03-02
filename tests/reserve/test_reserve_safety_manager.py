import hypothesis.strategies as st
import pytest
from brownie.test import given
from tests.reserve import object_creation
from tests.reserve.reserve_math_implementation import (
    build_metadata,
    calculate_ideal_weights,
    calculate_weights_and_total,
    is_mint_safe,
    is_redeem_safe,
    safe_to_execute_outside_epsilon,
    update_metadata_with_epsilon_status,
    update_metadata_with_price_safety,
    update_vault_with_price_safety,
    vault_weight_off_peg_falls,
)
from tests.support import constants
from tests.support.quantized_decimal import QuantizedDecimal as D
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
    weight_generator,
    price_generator,
    boolean_generator,
    boolean_generator,
    boolean_generator,
)

global_metadatas = st.tuples(
    boolean_generator, boolean_generator, boolean_generator, boolean_generator
)


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


# @given(bundle_metadata=st.tuples(vault_lists(vault_metadatas), global_metadatas))
# def test_check_any_off_peg_vault_would_move_closer_to_ideal_weight(
#     reserve_safety_manager, bundle_metadata, mock_vaults
# ):
#     metadata = bundle_to_metadata(bundle_metadata, mock_vaults)

#     result_sol = reserve_safety_manager.vaultWeightWithOffPegFalls(metadata)
#     result_exp = vault_weight_off_peg_falls(metadata)

#     assert result_sol == result_exp


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
def test_build_metadata(reserve_safety_manager, order_bundle, mock_vaults):

    mint_order = object_creation.bundle_to_order(order_bundle, True, mock_vaults)

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
        assert (
            D(vault_metadata_array_sol[i][3])
            == scale(vault_metadata_array_exp[i][3]).approxed()
        )
        assert vault_metadata_array_sol[i][4] == vault_metadata_array_exp[i][4]
        assert vault_metadata_array_sol[i][5] == vault_metadata_array_exp[i][5]
        assert vault_metadata_array_sol[i][6] == vault_metadata_array_exp[i][6]
        assert vault_metadata_array_sol[i][7] == vault_metadata_array_exp[i][7]


# @given(bundle_metadata=st.tuples(vault_lists(vault_metadatas), global_metadatas))
# def test_update_metadata_with_epsilon_status(
#     reserve_safety_manager, bundle_metadata, mock_vaults
# ):
#     metadata = bundle_to_metadata(bundle_metadata, mock_vaults)

#     result_sol = reserve_safety_manager.updateMetaDataWithEpsilonStatus(metadata)
#     result_exp = update_metadata_with_epsilon_status(metadata)

#     assert result_sol[1] == result_exp[1]


# @given(bundle_vault_metadata=vault_metadatas)
# def test_update_vault_with_price_safety(
#     reserve_safety_manager,
#     bundle_vault_metadata,
#     mock_price_oracle,
#     dai,
#     usdc,
#     asset_registry,
#     admin,
#     mock_vaults,
# ):
#     asset_registry.setAssetAddress("DAI", dai)
#     asset_registry.addStableAsset(dai, {"from": admin})

#     asset_registry.setAssetAddress("USDC", usdc)
#     asset_registry.addStableAsset(usdc, {"from": admin})

#     vault_metadata = (mock_vaults[0],) + bundle_vault_metadata

#     mock_vaults[0].setTokens([usdc, dai])

#     mock_price_oracle.setUSDPrice(dai, D("1e18"))
#     mock_price_oracle.setUSDPrice(usdc, D("1e18"))
#     vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
#         vault_metadata
#     )

#     status_of_all_stablecoins = vault_metadata_sol[6]
#     assert status_of_all_stablecoins == True

#     mock_price_oracle.setUSDPrice(dai, D("0.8e18"))

#     vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
#         vault_metadata
#     )
#     status_of_all_stablecoins = vault_metadata_sol[6]
#     assert status_of_all_stablecoins == False

#     mock_price_oracle.setUSDPrice(dai, D("0.95e18"))

#     vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
#         vault_metadata
#     )
#     status_of_all_stablecoins = vault_metadata_sol[6]
#     assert status_of_all_stablecoins == True

#     mock_price_oracle.setUSDPrice(dai, D("0.94e18"))

#     vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
#         vault_metadata
#     )
#     status_of_all_stablecoins = vault_metadata_sol[6]
#     assert status_of_all_stablecoins == False


# @given(bundle_vault_metadata=vault_metadatas)
# def test_update_vault_with_price_safety_tiny_prices(
#     reserve_safety_manager,
#     bundle_vault_metadata,
#     mock_price_oracle,
#     abc,
#     sdt,
#     asset_registry,
#     mock_vaults,
# ):
#     asset_registry.setAssetAddress("ABC", abc)
#     asset_registry.setAssetAddress("SDT", sdt)

#     vault_metadata = (mock_vaults[0],) + bundle_vault_metadata
#     mock_vaults[0].setTokens([sdt, abc])

#     mock_price_oracle.setUSDPrice(abc, D("1e16"))
#     mock_price_oracle.setUSDPrice(sdt, D("1e16"))
#     vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
#         vault_metadata
#     )

#     prices_large_enough = vault_metadata_sol[7]
#     assert prices_large_enough == True

#     mock_price_oracle.setUSDPrice(abc, D("1e12"))
#     mock_price_oracle.setUSDPrice(sdt, D("1e12"))
#     vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
#         vault_metadata
#     )

#     prices_large_enough = vault_metadata_sol[7]
#     assert prices_large_enough == False

#     mock_price_oracle.setUSDPrice(abc, D("1e13"))
#     mock_price_oracle.setUSDPrice(sdt, D("1e13"))
#     vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
#         vault_metadata
#     )

#     prices_large_enough = vault_metadata_sol[7]
#     assert prices_large_enough == True

#     mock_price_oracle.setUSDPrice(abc, D("0.95e12"))
#     mock_price_oracle.setUSDPrice(sdt, D("1e13"))
#     vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
#         vault_metadata
#     )

#     prices_large_enough = vault_metadata_sol[7]
#     assert prices_large_enough == True

#     mock_price_oracle.setUSDPrice(abc, D("0.95e12"))
#     mock_price_oracle.setUSDPrice(sdt, D("0.95e12"))
#     vault_metadata_sol = reserve_safety_manager.updateVaultWithPriceSafety(
#         vault_metadata
#     )

#     prices_large_enough = vault_metadata_sol[7]
#     assert prices_large_enough == False


# @given(bundle_metadata=st.tuples(vault_lists(vault_metadatas), global_metadatas))
# def test_update_metadata_with_price_safety_peg(
#     bundle_metadata,
#     reserve_safety_manager,
#     asset_registry,
#     dai,
#     usdc,
#     admin,
#     mock_price_oracle,
#     mock_vaults,
# ):
#     if not bundle_metadata:
#         return
#     metadata = bundle_to_metadata(bundle_metadata, mock_vaults)

#     asset_registry.setAssetAddress("DAI", dai)
#     asset_registry.addStableAsset(dai, {"from": admin})

#     asset_registry.setAssetAddress("USDC", usdc)
#     asset_registry.addStableAsset(usdc, {"from": admin})

#     mock_vaults[0].setTokens([usdc, dai])

#     mock_price_oracle.setUSDPrice(dai, D("1e18"))
#     mock_price_oracle.setUSDPrice(usdc, D("1e18"))

#     updated_metadata = reserve_safety_manager.updateMetadataWithPriceSafety(metadata)
#     onenotonpeg = False
#     for vault in updated_metadata[0]:
#         if vault[6] == False:
#             onenotonpeg = True

#     if onenotonpeg:
#         assert updated_metadata[2] == False
#     else:
#         assert updated_metadata[2] == True

#     mock_price_oracle.setUSDPrice(usdc, D("0.92e18"))

#     updated_metadata = reserve_safety_manager.updateMetadataWithPriceSafety(metadata)
#     onenotonpeg = False
#     for vault in updated_metadata[0]:
#         if vault[6] == False:
#             onenotonpeg = True

#     if onenotonpeg:
#         assert updated_metadata[2] == False
#     else:
#         assert updated_metadata[2] == True


# @given(bundle_metadata=st.tuples(vault_lists(vault_metadatas), global_metadatas))
# def test_update_metadata_with_price_safety_tiny_prices(
#     bundle_metadata,
#     reserve_safety_manager,
#     abc,
#     sdt,
#     asset_registry,
#     mock_price_oracle,
#     mock_vaults,
# ):

#     metadata = bundle_to_metadata(bundle_metadata, mock_vaults)

#     asset_registry.setAssetAddress("ABC", abc)
#     asset_registry.setAssetAddress("SDT", sdt)

#     mock_price_oracle.setUSDPrice(abc, D("1e16"))
#     mock_price_oracle.setUSDPrice(sdt, D("1e16"))

#     mock_vaults[0].setTokens([abc, sdt])

#     updated_metadata = reserve_safety_manager.updateMetadataWithPriceSafety(metadata)
#     onevaultpricestoosmall = False
#     for vault in updated_metadata[0]:
#         if vault[7] == False:
#             onevaultpricestoosmall = True

#     if onevaultpricestoosmall:
#         assert updated_metadata[3] == False
#     else:
#         assert updated_metadata[3] == True

#     mock_price_oracle.setUSDPrice(sdt, D("1e12"))
#     mock_price_oracle.setUSDPrice(abc, D("1e12"))

#     updated_metadata = reserve_safety_manager.updateMetadataWithPriceSafety(metadata)
#     onevaultpricestoosmall = False
#     for vault in updated_metadata[0]:
#         if vault[7] == False:
#             onevaultpricestoosmall = True

#     if onevaultpricestoosmall:
#         assert updated_metadata[3] == False
#     else:
#         assert updated_metadata[3] == True


# @given(bundle_metadata=st.tuples(vault_lists(vault_metadatas), global_metadatas))
# def test_safe_to_execute_outside_epsilon(
#     bundle_metadata, reserve_safety_manager, mock_vaults
# ):

#     metadata = bundle_to_metadata(bundle_metadata, mock_vaults)

#     result_exp = safe_to_execute_outside_epsilon(metadata)

#     result_sol = reserve_safety_manager.safeToExecuteOutsideEpsilon(metadata)

#     assert result_exp == result_sol


# @given(
#     order_bundle=st.lists(
#         st.tuples(
#             price_generator,
#             weight_generator,
#             amount_generator,
#             price_generator,
#             amount_generator,
#             weight_generator,
#         ),
#         min_size=1,
#         max_size=1,
#     )
# )
# def test_is_mint_safe_normal(
#     reserve_safety_manager,
#     order_bundle,
#     asset_registry,
#     admin,
#     dai,
#     usdc,
#     sdt,
#     abc,
#     mock_price_oracle,
#     mock_vaults,
# ):
#     if not order_bundle:
#         return
#     (
#         initial_price,
#         initial_weight,
#         reserve_balance,
#         current_vault_price,
#         amount,
#         current_weight,
#     ) = [list(v) for v in zip(*order_bundle)]

#     mint_order = order_builder(
#         True,
#         initial_price,
#         initial_weight,
#         reserve_balance,
#         current_vault_price,
#         amount,
#         current_weight,
#         mock_vaults,
#     )

#     asset_registry.setAssetAddress("DAI", dai)
#     asset_registry.addStableAsset(dai, {"from": admin})

#     asset_registry.setAssetAddress("USDC", usdc)
#     asset_registry.addStableAsset(usdc, {"from": admin})

#     asset_registry.setAssetAddress("ABC", abc)
#     asset_registry.addStableAsset(abc, {"from": admin})

#     asset_registry.setAssetAddress("SDT", sdt)

#     tokens = [[usdc, dai], [usdc, sdt], [sdt, dai], [abc, dai], [usdc, abc]]

#     for i, token in enumerate(tokens):
#         mock_vaults[i].setTokens(token)

#     mock_price_oracle.setUSDPrice(dai, D("1e18"))
#     mock_price_oracle.setUSDPrice(usdc, D("1e18"))
#     mock_price_oracle.setUSDPrice(abc, D("1e18"))
#     mock_price_oracle.setUSDPrice(sdt, D("1e18"))

#     response = reserve_safety_manager.isMintSafe(mint_order)

#     response_expected = is_mint_safe(
#         mint_order, tokens, mock_price_oracle, asset_registry
#     )

#     assert response == response_expected


# @given(
#     order_bundle=st.lists(
#         st.tuples(
#             price_generator,
#             weight_generator,
#             amount_generator,
#             price_generator,
#             amount_generator,
#             weight_generator,
#         ),
#         min_size=2,
#         max_size=2,
#     )
# )
# def test_is_mint_safe_small_prices(
#     reserve_safety_manager,
#     order_bundle,
#     asset_registry,
#     admin,
#     dai,
#     usdc,
#     sdt,
#     abc,
#     mock_price_oracle,
#     mock_vaults,
# ):

#     (
#         initial_price,
#         initial_weight,
#         reserve_balance,
#         current_vault_price,
#         amount,
#         current_weight,
#     ) = [list(v) for v in zip(*order_bundle)]

#     mint_order = order_builder(
#         True,
#         initial_price,
#         initial_weight,
#         reserve_balance,
#         current_vault_price,
#         amount,
#         current_weight,
#         mock_vaults,
#     )

#     asset_registry.setAssetAddress("ABC", abc)

#     asset_registry.setAssetAddress("SDT", sdt)

#     asset_registry.setAssetAddress("DAI", dai)
#     asset_registry.addStableAsset(dai, {"from": admin})

#     asset_registry.setAssetAddress("USDC", usdc)
#     asset_registry.addStableAsset(usdc, {"from": admin})

#     tokens = [[abc, sdt], [dai, usdc]]

#     for i, token in enumerate(tokens):
#         mock_vaults[i].setTokens(token)

#     mock_price_oracle.setUSDPrice(abc, D("1e11"))
#     mock_price_oracle.setUSDPrice(sdt, D("1e11"))
#     mock_price_oracle.setUSDPrice(dai, D("1e18"))
#     mock_price_oracle.setUSDPrice(usdc, D("1e18"))

#     response = reserve_safety_manager.isMintSafe(mint_order)

#     response_expected = is_mint_safe(
#         mint_order, tokens, mock_price_oracle, asset_registry
#     )

#     assert response == response_expected == "55"


# @given(
#     order_bundle=st.lists(
#         st.tuples(
#             price_generator,
#             weight_generator,
#             amount_generator,
#             price_generator,
#             amount_generator,
#             weight_generator,
#         ),
#         min_size=1,
#         max_size=5,
#     )
# )
# def test_is_mint_safe_off_peg(
#     reserve_safety_manager,
#     order_bundle,
#     asset_registry,
#     admin,
#     dai,
#     usdc,
#     sdt,
#     abc,
#     mock_price_oracle,
#     mock_vaults,
# ):
#     if not order_bundle:
#         return
#     (
#         initial_price,
#         initial_weight,
#         reserve_balance,
#         current_vault_price,
#         amount,
#         current_weight,
#     ) = [list(v) for v in zip(*order_bundle)]

#     mint_order = order_builder(
#         True,
#         initial_price,
#         initial_weight,
#         reserve_balance,
#         current_vault_price,
#         amount,
#         current_weight,
#         mock_vaults,
#     )

#     asset_registry.setAssetAddress("DAI", dai)
#     asset_registry.addStableAsset(dai, {"from": admin})

#     asset_registry.setAssetAddress("USDC", usdc)
#     asset_registry.addStableAsset(usdc, {"from": admin})

#     asset_registry.setAssetAddress("ABC", abc)
#     asset_registry.addStableAsset(abc, {"from": admin})

#     asset_registry.setAssetAddress("SDT", sdt)

#     tokens = [[usdc, dai], [usdc, sdt], [sdt, dai], [abc, dai], [usdc, abc]]

#     for i, token in enumerate(tokens):
#         mock_vaults[i].setTokens(token)

#     mock_price_oracle.setUSDPrice(dai, D("0.8e18"))
#     mock_price_oracle.setUSDPrice(usdc, D("1e18"))
#     mock_price_oracle.setUSDPrice(abc, D("1e18"))
#     mock_price_oracle.setUSDPrice(sdt, D("1e18"))

#     response = reserve_safety_manager.isMintSafe(mint_order)

#     response_expected = is_mint_safe(
#         mint_order, tokens, mock_price_oracle, asset_registry
#     )

#     assert response == response_expected


# @given(
#     reserve_state=st.lists(
#         st.tuples(
#             price_generator,
#             weight_generator,
#             amount_generator,
#             price_generator,
#             amount_generator,
#             weight_generator,
#         ),
#         min_size=5,
#         max_size=5,
#     ),
#     no_of_vaults_in_order=st.integers(min_value=1, max_value=5),
# )
# def test_is_redeem_safe_normal(
#     reserve_safety_manager,
#     asset_registry,
#     admin,
#     dai,
#     usdc,
#     sdt,
#     abc,
#     mock_price_oracle,
#     mock_vaults,
#     no_of_vaults_in_order,
#     reserve_state,
# ):
#     if not reserve_state:
#         return
#     (
#         initial_price,
#         initial_weight,
#         reserve_balance,
#         current_vault_price,
#         amount,
#         current_weight,
#     ) = [list(v) for v in zip(*reserve_state)]

#     if current_vault_price == initial_price:
#         return

#     redeem_order = order_builder(
#         False,
#         initial_price,
#         initial_weight,
#         reserve_balance,
#         current_vault_price,
#         amount,
#         current_weight,
#         mock_vaults,
#         no_of_vaults_in_order,
#     )

#     asset_registry.setAssetAddress("DAI", dai)
#     asset_registry.addStableAsset(dai, {"from": admin})

#     asset_registry.setAssetAddress("USDC", usdc)
#     asset_registry.addStableAsset(usdc, {"from": admin})

#     asset_registry.setAssetAddress("ABC", abc)
#     asset_registry.addStableAsset(abc, {"from": admin})

#     asset_registry.setAssetAddress("SDT", sdt)

#     tokens = [[usdc, dai], [usdc, sdt], [sdt, dai], [abc, dai], [usdc, abc]]

#     all_reserve_vaults = reserve_builder(
#         initial_price, initial_weight, reserve_balance, current_vault_price, mock_vaults
#     )

#     for i, token in enumerate(tokens):
#         mock_vaults[i].setTokens(token)

#     mock_price_oracle.setUSDPrice(dai, D("1e18"))
#     mock_price_oracle.setUSDPrice(usdc, D("1e18"))
#     mock_price_oracle.setUSDPrice(abc, D("1e18"))
#     mock_price_oracle.setUSDPrice(sdt, D("1e18"))

#     response = reserve_safety_manager.isRedeemSafe(redeem_order)

#     response_expected = is_redeem_safe(
#         redeem_order, tokens, mock_price_oracle, asset_registry
#     )

#     assert response == response_expected


# @given(
#     order_bundle=st.lists(
#         st.tuples(
#             price_generator,
#             weight_generator,
#             amount_generator,
#             price_generator,
#             amount_generator,
#             weight_generator,
#         ),
#         min_size=2,
#         max_size=2,
#     )
# )
# def test_is_redeem_safe_small_prices(
#     reserve_safety_manager,
#     order_bundle,
#     asset_registry,
#     admin,
#     dai,
#     usdc,
#     sdt,
#     abc,
#     mock_price_oracle,
#     mock_vaults,
# ):
#     if not order_bundle:
#         return
#     (
#         initial_price,
#         initial_weight,
#         reserve_balance,
#         current_vault_price,
#         amount,
#         current_weight,
#     ) = [list(v) for v in zip(*order_bundle)]

#     redeem_order = order_builder(
#         False,
#         initial_price,
#         initial_weight,
#         reserve_balance,
#         current_vault_price,
#         amount,
#         current_weight,
#         mock_vaults,
#     )

#     asset_registry.setAssetAddress("ABC", abc)

#     asset_registry.setAssetAddress("SDT", sdt)

#     asset_registry.setAssetAddress("DAI", dai)
#     asset_registry.addStableAsset(dai, {"from": admin})

#     asset_registry.setAssetAddress("USDC", usdc)
#     asset_registry.addStableAsset(usdc, {"from": admin})

#     tokens = [[sdt, abc], [usdc, abc]]

#     for i, token in enumerate(tokens):
#         mock_vaults[i].setTokens(token)

#     mock_price_oracle.setUSDPrice(abc, D("1e11"))
#     mock_price_oracle.setUSDPrice(sdt, D("1e11"))
#     mock_price_oracle.setUSDPrice(dai, D("1e18"))
#     mock_price_oracle.setUSDPrice(usdc, D("1e18"))

#     response = reserve_safety_manager.isRedeemSafe(redeem_order)

#     response_expected = is_redeem_safe(
#         redeem_order, tokens, mock_price_oracle, asset_registry
#     )

#     if not response == "56" == response_expected:
#         assert response == response_expected == "55"
