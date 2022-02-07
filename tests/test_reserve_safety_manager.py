from decimal import Decimal as D

import hypothesis.strategies as st
import pytest
from brownie.network.state import Chain
from brownie.test import given
from brownie.test.managers.runner import RevertContextManager as reverts

POOL_ID = "0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080"
POOL_ID_2 = "0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000088"

balance_strategy = st.integers(min_value=0, max_value=1_000_000_000)

def test_would_vaults_remain_balanced(balancer_safety_checks, weights):
    vaults = 
    monetary_amounts = balancer_safety_checks.makeMonetaryAmounts(tokens, balances)
    weights = balancer_safety_checks.computeActualWeights(monetary_amounts)




