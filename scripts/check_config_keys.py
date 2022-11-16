from brownie import GyroConfig
from scripts.utils import with_deployed
from tests.support import config_keys


@with_deployed(GyroConfig)
def main(gyro_config):
    for key in dir(config_keys):
        if not "A" <= key[0] <= "Z":
            continue
        encoded_key = getattr(config_keys, key)
        if not gyro_config.hasKey(encoded_key):
            print("Missing key:", key)
            continue
        if key.endswith("ADDRESS"):
            value = gyro_config.getAddress(encoded_key)
        else:
            value = gyro_config.getUint(encoded_key)
        print(f"{key}: {value}")
