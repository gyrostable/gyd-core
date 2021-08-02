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


def test_get_pool_ids(bal_pool_registry, dai, usdc, usdt):

    pool_id_1 = brownie.convert.to_bytes(1111, type_str="bytes32")
    tx1 = bal_pool_registry.registerPoolId(dai, pool_id_1)
    tx2 = bal_pool_registry.getPoolIds(dai)

    assert brownie.convert.to_bytes(tx2[0], type_str="bytes32 ") == pool_id_1


def test_get_pool_ids_when_multiple(bal_pool_registry, dai, usdc, usdt):

    pool_id_1 = brownie.convert.to_bytes(1111, type_str="bytes32")
    tx1 = bal_pool_registry.registerPoolId(dai, pool_id_1)

    pool_id_2 = brownie.convert.to_bytes(2222, type_str="bytes32")
    pool_id_3 = brownie.convert.to_bytes(3333, type_str="bytes32")

    tx2 = bal_pool_registry.registerPoolId(usdt, pool_id_2)
    tx3 = bal_pool_registry.registerPoolId(usdc, pool_id_3)

    tx4 = bal_pool_registry.getPoolIds(dai)
    tx5 = bal_pool_registry.getPoolIds(usdt)
    tx6 = bal_pool_registry.getPoolIds(usdc)

    assert brownie.convert.to_bytes(tx4[0], type_str="bytes32") == pool_id_1
    assert brownie.convert.to_bytes(tx5[0], type_str="bytes32") == pool_id_2
    assert brownie.convert.to_bytes(tx6[0], type_str="bytes32") == pool_id_3


def test_get_pool_ids_when_multiple_per_token(bal_pool_registry, dai, usdc, usdt):

    pool_id_1 = brownie.convert.to_bytes(1111, type_str="bytes32")
    pool_id_2 = brownie.convert.to_bytes(2222, type_str="bytes32")
    pool_id_3 = brownie.convert.to_bytes(3333, type_str="bytes32")

    tx1 = bal_pool_registry.registerPoolId(dai, pool_id_1)
    tx2 = bal_pool_registry.registerPoolId(dai, pool_id_2)
    tx3 = bal_pool_registry.registerPoolId(dai, pool_id_3)

    tx4 = bal_pool_registry.getPoolIds(dai)

    assert brownie.convert.to_bytes(tx4[0], type_str="bytes32") == pool_id_1
    assert brownie.convert.to_bytes(tx4[1], type_str="bytes32") == pool_id_2
    assert brownie.convert.to_bytes(tx4[2], type_str="bytes32") == pool_id_3


def test_deregistration(bal_pool_registry, dai):

    pool_id_1 = brownie.convert.to_bytes(1111, type_str="bytes32")
    pool_id_2 = brownie.convert.to_bytes(2222, type_str="bytes32")
    pool_id_3 = brownie.convert.to_bytes(3333, type_str="bytes32")

    tx1 = bal_pool_registry.registerPoolId(dai, pool_id_1)
    tx2 = bal_pool_registry.registerPoolId(dai, pool_id_2)
    tx3 = bal_pool_registry.registerPoolId(dai, pool_id_3)

    tx4 = bal_pool_registry.getPoolIds(dai)
    assert len(tx4) == 3

    bal_pool_registry.deregisterPoolId(dai, pool_id_1)

    tx5 = bal_pool_registry.getPoolIds(dai)
    assert len(tx5) == 2

    bal_pool_registry.deregisterPoolId(dai, pool_id_2)

    tx6 = bal_pool_registry.getPoolIds(dai)
    assert len(tx6) == 1
