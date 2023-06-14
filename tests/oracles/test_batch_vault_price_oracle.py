from brownie import ZERO_ADDRESS
from tests.support.types import PersistedVaultMetadata, PricedToken, VaultInfo


def _dummy_vault(tokens):
    return VaultInfo(
        vault=ZERO_ADDRESS,
        decimals=18,
        underlying=ZERO_ADDRESS,
        price=0,
        persisted_metadata=PersistedVaultMetadata(0, 0, 0, 0),
        reserve_balance=0,
        current_weight=0,
        target_weight=0,
        priced_tokens=[PricedToken(t, False, 0) for t in tokens],
    )


def test_construct_tokens_array(batch_vault_price_oracle, dai, usdc, weth, usdt):
    vaults = [_dummy_vault([dai, weth]), _dummy_vault([dai, usdt, usdc])]
    tokens = batch_vault_price_oracle.constructTokensArray(vaults)
    assert len(tokens) == 4
    sorted_tokens = sorted(
        bytes.fromhex(t.address[2:]) for t in [dai, weth, usdc, usdt]
    )
    assert [bytes.fromhex(t[2:]) for t in tokens] == sorted_tokens
