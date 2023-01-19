import pytest
from brownie.test import given
import hypothesis.strategies as st


@pytest.fixture(scope="module")
def testing_array(TestingArray, admin):
    return admin.deploy(TestingArray)


st_addresses = st.integers(min_value=0, max_value=2**160).map(
    lambda x: "0x" + x.to_bytes(20, "big").hex()
)


@given(addresses=st.lists(st_addresses, min_size=0, max_size=10))
def test_sort(testing_array, addresses):
    assert testing_array.sort(addresses) == sorted(addresses)


@given(addresses=st.lists(st_addresses, min_size=0, max_size=10))
def test_dedup(testing_array, addresses):
    sorted_addresses = sorted(addresses)
    assert testing_array.dedup(sorted_addresses) == sorted(set(addresses))
