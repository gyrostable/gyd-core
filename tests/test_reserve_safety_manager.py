from decimal import Decimal as D

import hypothesis.strategies as st
import pytest
from brownie.network.state import Chain
from brownie.test import given
from brownie.test.managers.runner import RevertContextManager as reverts

from tests.support.utils import scale

POOL_ID = "0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080"
POOL_ID_2 = "0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000088"

weight_strategy = st.integers(min_value=0.1e17, max_value=1e18)


@given(weights=st.tuples(balance_strategy, balance_strategy))
def test_would_vaults_remain_balanced(balancer_safety_checks, weights):
    ideal_weight = weights[0]
    requested_weight = weights[1]
