import pytest


@pytest.fixture()
def lp_token_exchanger_registry(admin, LPTokenExchangerRegistry):
    return admin.deploy(LPTokenExchangerRegistry)


@pytest.fixture()
def mock_vault_router(admin, MockVaultRouter):
    return admin.deploy(MockVaultRouter)
