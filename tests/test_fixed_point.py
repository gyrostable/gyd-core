import hypothesis.strategies as st
import pytest
from brownie.test import given

from tests.support.quantized_decimal import QuantizedDecimal as D
from tests.support.utils import scale, to_decimal

base_generator = st.integers(min_value=int(scale(("0.001"))), max_value=int(scale(1)))

exp_generator = st.integers(min_value=1, max_value=100)


@given(numbers=st.tuples(base_generator, exp_generator))
def test_int_pow_down(testing_fixed_point, numbers):
    result = testing_fixed_point.intPowDownTest(numbers[0], numbers[1])
    descaled_number = numbers[0] / 10**18
    expected_result = descaled_number ** numbers[1]
    assert D(result) == scale(D(expected_result)).approxed()
