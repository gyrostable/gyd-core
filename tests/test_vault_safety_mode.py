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
