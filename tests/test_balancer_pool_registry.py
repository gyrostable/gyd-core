import brownie
from brownie import accounts


def test_get_pool_ids(bal_pool_registry, dai):
    pool_id_1 = brownie.convert.to_bytes(1111, type_str="bytes32")
    tx1 = bal_pool_registry.registerPoolId(dai, pool_id_1)

    assert (
        brownie.convert.to_bytes(
            tx1.events["PoolIDRegistered"]["poolId"], type_str="bytes32"
        )
        == pool_id_1
    )
    assert tx1.events["PoolIDRegistered"]["underlyingTokenAddress"] == dai


def test_get_pool_ids_multiple(bal_pool_registry, dai, usdc, usdt):
    pool_id_2 = brownie.convert.to_bytes(2222, type_str="bytes32")
    pool_id_3 = brownie.convert.to_bytes(3333, type_str="bytes32")

    tx2 = bal_pool_registry.registerPoolId(usdt, pool_id_2)
    tx3 = bal_pool_registry.registerPoolId(usdc, pool_id_3)

    assert tx2.events["PoolIDRegistered"]["underlyingTokenAddress"] == usdt
    assert tx3.events["PoolIDRegistered"]["underlyingTokenAddress"] == usdc

    assert (
        brownie.convert.to_bytes(
            tx2.events["PoolIDRegistered"]["poolId"], type_str="bytes32"
        )
        == pool_id_2
    )

    assert (
        brownie.convert.to_bytes(
            tx3.events["PoolIDRegistered"]["poolId"], type_str="bytes32"
        )
        == pool_id_3
    )
