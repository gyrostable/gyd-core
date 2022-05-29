from typing import List, Tuple

from brownie import interface  # type: ignore
from eth_abi.abi import encode_abi
from tests.support.types import JoinPoolRequest
from tests.support.utils import JoinKind


def join_pool(
    account: str,
    vault,
    pool_id: str,
    amounts: List[Tuple[str, int]],
    join_kind=JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT,
):
    amounts = sorted(amounts, key=lambda b: int(b[0], 16))
    for token, amount in amounts:
        interface.ERC20(token).approve(vault, amount, {"from": account})

    tokens, balances = zip(*amounts)
    abi = ["uint256", "uint256[]", "uint256"]
    data = [join_kind, balances, 0]
    encoded_user_data = encode_abi(abi, data)

    return vault.joinPool(
        pool_id,
        account,
        account,
        JoinPoolRequest(
            tokens,  # type: ignore
            balances,  # type: ignore
            encoded_user_data,
        ),
        {"from": account},
    )
