from typing import Iterable, Tuple

import hypothesis.strategies as st
import pytest
from brownie.test import given
from numpy import exp

from tests.reserve.reserve_math_implementation import \
    calculate_weights_and_total
from tests.support.quantized_decimal import QuantizedDecimal as D
from tests.support.utils import scale, to_decimal

# POOL_ID = "0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080"

# pytestmark = pytest.mark.usefixtures("set_data_for_mock_bal_vault")

amount_generator = st.integers(min_value=int(scale("0.001")), max_value=int(scale(1_000_000_000)))
price_generator = st.integers(min_value=int(scale("0.001")), max_value=int(scale(1_000_000_000)))

@given(amounts_and_prices=st.lists(st.tuples(amount_generator, price_generator)))
def test_calculate_weights_and_total(reserve_safety_manager, amounts_and_prices):
    if not amounts_and_prices:
        return

    amounts, prices = [list(v) for v in zip(*amounts_and_prices)]

    weights_exp, total_exp = calculate_weights_and_total(to_decimal(amounts), to_decimal(prices))
    weights_sol, total_sol = reserve_safety_manager.calculateWeightsAndTotal(amounts, prices)

    approxed_expected_weights = [scale(i).approxed() for i in weights_exp]

    assert to_decimal(weights_sol) == approxed_expected_weights
    assert total_exp == scale(total_sol).approxed()






