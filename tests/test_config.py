import pytest
from brownie import ZERO_ADDRESS
from brownie.test.managers.runner import RevertContextManager as reverts

from tests.support.utils import format_to_bytes, scale
from tests.support import error_codes

FEE_BANK_DUMMY_ADDRESS = "0x0057Ea85A6B3ccE0f4c2ee16EC34dA3a7b3DCE14"


CONFIG_TYPES = {
    "address": 1,
    "uint": 2,
}


@pytest.mark.parametrize(
    "config_type,plain_key,value",
    [
        ("uint", "MINT_FEE", scale(2, 16)),
        ("address", "FEE_BANK", FEE_BANK_DUMMY_ADDRESS),
    ],
)
def test_set_config(admin, alice, gyro_config, config_type, plain_key, value):
    key = format_to_bytes(plain_key, 32, output_hex=True)
    getter = getattr(gyro_config, "get" + config_type.capitalize())
    setter = getattr(gyro_config, "set" + config_type.capitalize())
    zero_value = ZERO_ADDRESS if config_type == "address" else 0

    assert not gyro_config.hasKey(key)

    with reverts(error_codes.KEY_NOT_FOUND):
        getter(key)

    tx = setter(key, value, {"from": admin})
    assert gyro_config.hasKey(key)
    assert getter(key) == value
    assert len(tx.events["ConfigChanged"]) == 1
    event = tx.events["ConfigChanged"][0]
    assert event["key"] == key
    assert event["previousValue"] == zero_value
    assert event["newValue"] == value

    with reverts(error_codes.NOT_AUTHORIZED):
        setter(key, value, {"from": alice})

    other_value_type = scale(1) if isinstance(value, str) else FEE_BANK_DUMMY_ADDRESS
    other_type = "address" if config_type == "uint" else "uint"
    other_setter = getattr(gyro_config, "set" + other_type.capitalize())

    with reverts(error_codes.INVALID_ARGUMENT):
        other_setter(key, other_value_type, {"from": admin})


@pytest.mark.parametrize(
    "config_type,plain_key,value",
    [
        ("uint", "MINT_FEE", scale(2, 16)),
        ("address", "FEE_BANK", FEE_BANK_DUMMY_ADDRESS),
    ],
)
def test_unset_config(admin, gyro_config, config_type, plain_key, value):
    key = format_to_bytes(plain_key, 32, output_hex=True)
    getter = getattr(gyro_config, "get" + config_type.capitalize())
    setter = getattr(gyro_config, "set" + config_type.capitalize())

    with reverts(error_codes.KEY_NOT_FOUND):
        gyro_config.unset(key)

    setter(key, value, {"from": admin})
    assert gyro_config.hasKey(key)
    tx = gyro_config.unset(key)

    assert tx.events["ConfigUnset"]["key"] == key

    assert not gyro_config.hasKey(key)
    with reverts(error_codes.KEY_NOT_FOUND):
        getter(key)


@pytest.mark.parametrize(
    "config_type,plain_key,value",
    [
        ("uint", "MINT_FEE", scale(2, 16)),
        ("address", "FEE_BANK", FEE_BANK_DUMMY_ADDRESS),
    ],
)
def test_freeze_config(admin, gyro_config, config_type, plain_key, value):
    key = format_to_bytes(plain_key, 32, output_hex=True)
    getter = getattr(gyro_config, "get" + config_type.capitalize())
    setter = getattr(gyro_config, "set" + config_type.capitalize())

    setter(key, value, {"from": admin})
    assert gyro_config.hasKey(key)
    assert gyro_config.getConfigMeta(key) == (CONFIG_TYPES[config_type], False)

    tx = gyro_config.freeze(key)

    assert tx.events["ConfigFrozen"]["key"] == key

    assert gyro_config.hasKey(key)
    assert gyro_config.getConfigMeta(key) == (CONFIG_TYPES[config_type], True)

    assert getter(key) == value

    with reverts(error_codes.KEY_FROZEN):
        setter(key, value, {"from": admin})
