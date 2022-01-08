import brownie
import pytest
from brownie import ZERO_ADDRESS

from tests.support.utils import format_to_bytes, scale

FEE_BANK_DUMMY_ADDRESS = "0x0057Ea85A6B3ccE0f4c2ee16EC34dA3a7b3DCE14"


@pytest.mark.parametrize(
    "config_type,plain_key,value",
    [
        ("uint", "MINT_FEE", scale(2, 16)),
        ("address", "FEE_BANK", FEE_BANK_DUMMY_ADDRESS),
    ],
)
def test_set_config(admin, alice, gyro_config, config_type, plain_key, value):
    key = format_to_bytes(plain_key, 32)
    getter = getattr(gyro_config, "get" + config_type.capitalize())
    setter = getattr(gyro_config, "set" + config_type.capitalize())
    zero_value = ZERO_ADDRESS if config_type == "address" else 0

    assert getter(key) == zero_value
    tx = setter(key, value, {"from": admin})
    assert getter(key) == value
    assert len(tx.events["ConfigChanged"]) == 1
    event = tx.events["ConfigChanged"][0]
    assert event["key"].hex() == key.hex()
    assert event["previousValue"] == zero_value
    assert event["newValue"] == value

    with brownie.reverts("30"):  # type: ignore
        setter(key, value, {"from": alice})
