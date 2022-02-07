from decimal import Decimal as D

import hypothesis.strategies as st
import pytest
from brownie.network.state import Chain
from brownie.test import given
from brownie.test.managers.runner import RevertContextManager as reverts

from tests.support import error_codes
from tests.support.utils import scale

chain = Chain()

POOL_ID = "0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080"

POOL_ID_2 = "0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000088"

pytestmark = pytest.mark.usefixtures("set_data_for_mock_bal_vault")

balance_strategy = st.integers(min_value=scale(0), max_value=scale(1_000_000_000))


@pytest.fixture(scope="module", autouse=True)
def set_stablecoin_usd_price_oracle(dai, usdc, usdt, mock_price_oracle):
    mock_price_oracle.setUSDPrice(dai, 10 ** 18)
    mock_price_oracle.setUSDPrice(usdc, 10 ** 18)
    mock_price_oracle.setUSDPrice(usdt, 1e18)


def test_is_pool_paused(balancer_safety_checks, mock_balancer_pool):
    mock_balancer_pool.setPausedState(False, 2, 4)
    pool_state = balancer_safety_checks.isPoolPaused(POOL_ID)
    assert pool_state == False


def test_is_pool_paused_when_paused(balancer_safety_checks, mock_balancer_pool):
    mock_balancer_pool.setPausedState(True, 2, 4)
    pool_state = balancer_safety_checks.isPoolPaused(POOL_ID)
    assert pool_state == True


@given(balances=st.tuples(balance_strategy, balance_strategy))
def test_make_monetary_amounts(balancer_safety_checks, dai, usdc, balances):
    tokens = [dai, usdc]
    monetary_amounts = balancer_safety_checks.makeMonetaryAmounts(tokens, balances)
    assert monetary_amounts == [[dai, balances[0]], [usdc, balances[1]]]


@given(balances=st.tuples(balance_strategy, balance_strategy))
def test_compute_actual_weights(balancer_safety_checks, dai, usdc, balances):
    tokens = [dai, usdc]
    monetary_amounts = balancer_safety_checks.makeMonetaryAmounts(tokens, balances)
    weights = balancer_safety_checks.computeActualWeights(monetary_amounts)

    if (balances[0] == 0) and (balances[1] == 0):
        assert sum(list(weights)) == 0
    else:
        assert sum(list(weights)) == pytest.approx(10 ** 18)


def test_are_pool_weights_close_to_expected_imbalanced(
    balancer_safety_checks, dai, usdc, mock_balancer_pool, mock_balancer_vault
):
    tokens = [dai, usdc]
    balances = [3e20, 2e20]

    mock_balancer_vault.setPoolTokens(POOL_ID, tokens, balances)
    mock_balancer_pool.setNormalizedWeights([5e17, 5e17])

    assert balancer_safety_checks.arePoolAssetWeightsCloseToExpected(POOL_ID) == False


# @pytest.mark.skip()
def test_are_pool_weights_close_to_expected_exact(
    balancer_safety_checks, dai, usdc, mock_balancer_pool, mock_balancer_vault
):
    tokens = [dai, usdc]
    balances = [2e20, 2e20]
    mock_balancer_vault.setPoolTokens(POOL_ID, tokens, balances)
    mock_balancer_pool.setNormalizedWeights([5e17, 5e17])

    assert balancer_safety_checks.arePoolAssetWeightsCloseToExpected(POOL_ID) == True


# @pytest.mark.skip()
def test_are_all_pool_stablecoins_close_to_peg(
    balancer_safety_checks,
    mock_balancer_vault,
    dai,
    usdc,
    mock_price_oracle,
    asset_registry,
):
    tokens = [dai, usdc]
    balances = [3e20, 2e20]
    asset_registry.setAssetAddress("DAI", dai)
    asset_registry.addStableAsset(dai)
    mock_balancer_vault.setPoolTokens(POOL_ID, tokens, balances)
    response = balancer_safety_checks.areAllPoolStablecoinsCloseToPeg(POOL_ID)
    assert response == True

    mock_price_oracle.setUSDPrice(dai, 0.9e18)
    off_peg = balancer_safety_checks.areAllPoolStablecoinsCloseToPeg(POOL_ID)
    assert off_peg == False

    mock_price_oracle.setUSDPrice(dai, 1.1e18)
    off_peg = balancer_safety_checks.areAllPoolStablecoinsCloseToPeg(POOL_ID)
    assert off_peg == False

    mock_price_oracle.setUSDPrice(dai, 0.98e18)
    off_peg = balancer_safety_checks.areAllPoolStablecoinsCloseToPeg(POOL_ID)
    assert off_peg == False

    mock_price_oracle.setUSDPrice(dai, 1.02e18)
    off_peg = balancer_safety_checks.areAllPoolStablecoinsCloseToPeg(POOL_ID)
    assert off_peg == False

    mock_price_oracle.setUSDPrice(dai, 0.99e18)
    off_peg = balancer_safety_checks.areAllPoolStablecoinsCloseToPeg(POOL_ID)
    assert off_peg == True

    mock_price_oracle.setUSDPrice(dai, 1.01e18)
    off_peg = balancer_safety_checks.areAllPoolStablecoinsCloseToPeg(POOL_ID)
    assert off_peg == True


# @pytest.mark.skip()
def test_ensure_pools_safe(
    balancer_safety_checks,
    mock_balancer_pool,
    dai,
    usdc,
    mock_balancer_vault,
    asset_registry,
    mock_price_oracle,
):
    tokens = [dai, usdc]
    balances = [2e20, 2e20]

    mock_balancer_vault.setPoolTokens(POOL_ID, tokens, balances)

    mock_balancer_pool.setNormalizedWeights([5e17, 5e17])
    mock_balancer_pool.setPausedState(True, 2, 4)

    asset_registry.setAssetAddress("DAI", dai)
    asset_registry.addStableAsset(dai)

    with reverts(error_codes.POOL_IS_PAUSED):
        balancer_safety_checks.ensurePoolsSafe([POOL_ID])

    mock_balancer_pool.setPausedState(False, 2, 4)
    new_balances = [2e20, 3e20]
    mock_balancer_vault.setPoolTokens(POOL_ID, tokens, new_balances)

    with reverts(error_codes.ASSETS_NOT_CLOSE_TO_POOL_WEIGHTS):
        balancer_safety_checks.ensurePoolsSafe([POOL_ID])

    mock_balancer_vault.setPoolTokens(POOL_ID, tokens, balances)

    mock_price_oracle.setUSDPrice(dai, 0.9e18)

    with reverts(error_codes.STABLECOIN_IN_POOL_NOT_CLOSE_TO_PEG):
        balancer_safety_checks.ensurePoolsSafe([POOL_ID])


# @pytest.mark.skip()
def test_ensure_pools_safe_two_pools(
    balancer_safety_checks,
    mock_balancer_pool,
    mock_balancer_pool_two,
    dai,
    usdc,
    usdt,
    mock_balancer_vault,
    asset_registry,
    mock_price_oracle,
):
    tokens_pool_one = [dai, usdc]
    balances_pool_one = [2e20, 2e20]

    tokens_pool_two = [usdt, usdc]
    balances_pool_two = [2e20, 2e20]

    mock_balancer_vault.setPoolTokens(POOL_ID, tokens_pool_one, balances_pool_one)
    mock_balancer_vault.setPoolTokens(POOL_ID_2, tokens_pool_two, balances_pool_two)

    mock_balancer_pool.setNormalizedWeights([5e17, 5e17])
    mock_balancer_pool.setPausedState(False, 2, 4)

    mock_balancer_pool_two.setNormalizedWeights([5e17, 5e17])
    mock_balancer_pool_two.setPausedState(True, 2, 4)

    asset_registry.setAssetAddress("DAI", dai)
    asset_registry.setAssetAddress("USDC", usdc)
    asset_registry.setAssetAddress("USDT", usdt)

    asset_registry.addStableAsset(dai)
    asset_registry.addStableAsset(usdc)
    asset_registry.addStableAsset(usdt)

    with reverts(error_codes.POOL_IS_PAUSED):
        balancer_safety_checks.ensurePoolsSafe([POOL_ID, POOL_ID_2])

    mock_balancer_pool_two.setPausedState(False, 2, 4)
    balances = [2e20, 3e20]
    mock_balancer_vault.setPoolTokens(POOL_ID_2, tokens_pool_two, balances)

    with reverts(error_codes.ASSETS_NOT_CLOSE_TO_POOL_WEIGHTS):
        balancer_safety_checks.ensurePoolsSafe([POOL_ID, POOL_ID_2])

    mock_balancer_vault.setPoolTokens(POOL_ID_2, tokens_pool_two, balances_pool_two)

    mock_price_oracle.setUSDPrice(usdt, 0.9e18)

    with reverts(error_codes.STABLECOIN_IN_POOL_NOT_CLOSE_TO_PEG):
        balancer_safety_checks.ensurePoolsSafe([POOL_ID, POOL_ID_2])
