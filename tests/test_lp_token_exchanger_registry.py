import brownie

from tests.support import error_codes


DUMMY_TOKEN_ADDRESS = "0x8cCCDAB8Aac657deC7F14b6C68b9b6b2C5B1b4Ad"
DUMMY_EXCHANGER_ADDRESS = "0x5e8520ee0deE4dB8fb73de5DB77f16AbC21142e3"


def test_get_not_registered_token(lp_token_exchanger_registry):
    with brownie.reverts(error_codes.EXCHANGER_NOT_FOUND):  # type: ignore
        lp_token_exchanger_registry.getTokenExchanger(DUMMY_TOKEN_ADDRESS)


def test_register_token_exchanger(lp_token_exchanger_registry):
    lp_token_exchanger_registry.registerTokenExchanger(
        DUMMY_TOKEN_ADDRESS, DUMMY_EXCHANGER_ADDRESS
    )
    exchanger = lp_token_exchanger_registry.getTokenExchanger(DUMMY_TOKEN_ADDRESS)
    assert exchanger == DUMMY_EXCHANGER_ADDRESS


def test_deregister_token_exchanger(lp_token_exchanger_registry):
    lp_token_exchanger_registry.registerTokenExchanger(
        DUMMY_TOKEN_ADDRESS, DUMMY_EXCHANGER_ADDRESS
    )
    lp_token_exchanger_registry.deregisterTokenExchanger(DUMMY_TOKEN_ADDRESS)
    with brownie.reverts(error_codes.EXCHANGER_NOT_FOUND):  # type: ignore
        lp_token_exchanger_registry.getTokenExchanger(DUMMY_TOKEN_ADDRESS)
