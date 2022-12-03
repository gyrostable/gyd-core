from brownie import ETH_ADDRESS, ZERO_ADDRESS
from brownie.network import chain

STABLE_COINS = ["DAI", "USDT", "USDC", "GUSD", "HUSD", "TUSD", "USDP", "LUSD"]

_token_addresses = {
    1: {
        "DAI": "0x6B175474E89094C44Da98b954EedeAC495271d0F",
        "WBTC": "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
        "USDC": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        "WETH": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
        "CRV": "0xD533a949740bb3306d119CC777fa900bA034cd52",
        "TUSD": "0x0000000000085d4780B73119b644AE5ecd22b376",
        "USDP": "0x8E870D67F660D95d5be530380D0eC0bd388289E1",
        "PAXG": "0x45804880De22913dAFE09f4980848ECE6EcbAf78",
        "AAVE": "0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9",
        "LUSD": "0x5f98805A4E8be255a32880FDeC7F6728C6568bA0",
        "COMP": "0xc00e94Cb662C3520282E6f5717214004A7f26888",
        "USDT": "0xdAC17F958D2ee523a2206206994597C13D831ec7",
        "GUSD": "0x056Fd409E1d7A124BD7017459dFEa2F387b6d5Cd",
        "HUSD": "0xdF574c24545E5FfEcb9a659c229253D4111d87e1",
    },
    137: {
        "DAI": "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063",
        "WBTC": "0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6",
        "USDC": "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
        "WETH": "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",
        "CRV": "0x172370d5Cd63279eFa6d502DAB29171933a610AF",
        "TUSD": "0x2e1AD108fF1D8C782fcBbB89AAd783aC49586756",
        "PAXG": "0x553d3D295e0f695B9228246232eDF400ed3560B5",
        "AAVE": "0xD6DF932A45C0f255f85145f286eA0b292B21C90B",
        "COMP": "0x8505b9d2254A7Ae468c0E9dd10Ccea3A837aef5c",
        "USDT": "0xc2132D05D31c914a87C6611C10748AEb04B58e8F",
        "GUSD": "0xC8A94a3d3D2dabC3C1CaffFFDcA6A7543c3e3e65",
        "HUSD": "0x2088C47Fc0c78356c622F79dBa4CbE1cCfA84A91",
        "UNI": "0xb33EaAd8d922B1083446DC23f610c2567fB5180f",
        "LINK": "0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39",
        "WMATIC": "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
        "BUSD": "0x9C9e5fD8bbc25984B178FdCE6117Defa39d2db39",
    },
}


def _token_address(name) -> str:
    chain_id = chain.id
    if chain_id == 1337:
        chain_id = 1
    if chain_id not in _token_addresses:
        raise ValueError(f"chain {chain_id} not supported")
    return _token_addresses[chain_id].get(name, ZERO_ADDRESS)


class TokenAddresses:
    ETH = ETH_ADDRESS

    @classmethod
    @property
    def DAI(cls):
        return _token_address("DAI")

    @classmethod
    @property
    def WBTC(cls):
        return _token_address("WBTC")

    @classmethod
    @property
    def USDC(cls):
        return _token_address("USDC")

    @classmethod
    @property
    def WETH(cls):
        return _token_address("WETH")

    @classmethod
    @property
    def CRV(cls):
        return _token_address("CRV")

    @classmethod
    @property
    def TUSD(cls):
        return _token_address("TUSD")

    @classmethod
    @property
    def USDP(cls):
        return _token_address("USDP")

    @classmethod
    @property
    def PAXG(cls):
        return _token_address("PAXG")

    @classmethod
    @property
    def AAVE(cls):
        return _token_address("AAVE")

    @classmethod
    @property
    def LUSD(cls):
        return _token_address("LUSD")

    @classmethod
    @property
    def COMP(cls):
        return _token_address("COMP")

    @classmethod
    @property
    def USDT(cls):
        return _token_address("USDT")

    @classmethod
    @property
    def BUSD(cls):
        return _token_address("BUSD")

    @classmethod
    @property
    def GUSD(cls):
        return _token_address("GUSD")

    @classmethod
    @property
    def HUSD(cls):
        return _token_address("HUSD")

    @classmethod
    @property
    def UNI(cls):
        return _token_address("UNI")

    @classmethod
    @property
    def LINK(cls):
        return _token_address("LINK")

    @classmethod
    @property
    def WMATIC(cls):
        return _token_address("WMATIC")


_chainlink_feeds = {
    1: {
        "ETH_USD_FEED": "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419",
        "DAI_USD_FEED": "0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9",
        "WBTC_USD_FEED": "0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c",
        "CRV_USD_FEED": "0xCd627aA160A6fA45Eb793D19Ef54f5062F20f33f",
        "USDC_USD_FEED": "0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6",
        "USDT_USD_FEED": "0x3E7d1eAB13ad0104d2750B8863b489D65364e32D",
    },
    137: {
        "ETH_USD_FEED": "0xF9680D99D6C9589e2a93a78A04A279e509205945",
        "DAI_USD_FEED": "0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D",
        "WBTC_USD_FEED": "0xDE31F8bFBD8c84b5360CFACCa3539B938dd78ae6",
        "USDC_USD_FEED": "0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7",
        "USDT_USD_FEED": "0x0A6513e40db6EB1b165753AD52E80663aeA50545",
        "MATIC_USD_FEED": "0xAB594600376Ec9fD91F8e885dADF0CE036862dE0",
        "LINK_USD_FEED": "0xd9FFdb71EbE7496cC440152d43986Aae0AB76665",
        "AAVE_USD_FEED": "0x72484B12719E23115761D5DA1646945632979bB6",
        "UNI_USD_FEED": "0xdf0Fb4e4F928d2dCB76f438575fDD8682386e13C",
        "TUSD_USD_FEED": "0x7c5d415b64312d38c56b54358449d0a4058339d2",
        "BUSD_USD_FEED": "0xe0dc07d5ed74741ceeda61284ee56a2a0f7a4cc9",
    },
}


def _chainlink_feed(name) -> str:
    chain_id = chain.id
    if chain_id == 1337:
        chain_id = 1
    if chain_id not in _token_addresses:
        raise ValueError(f"chain {chain_id} not supported")
    return _chainlink_feeds[chain_id].get(name, ZERO_ADDRESS)


class ChainlinkFeeds:
    @classmethod
    @property
    def ETH_USD_FEED(cls):
        return _chainlink_feed("ETH_USD_FEED")

    @classmethod
    @property
    def DAI_USD_FEED(cls):
        return _chainlink_feed("DAI_USD_FEED")

    @classmethod
    @property
    def WBTC_USD_FEED(cls):
        return _chainlink_feed("WBTC_USD_FEED")

    @classmethod
    @property
    def CRV_USD_FEED(cls):
        return _chainlink_feed("CRV_USD_FEED")

    @classmethod
    @property
    def USDC_USD_FEED(cls):
        return _chainlink_feed("USDC_USD_FEED")

    @classmethod
    @property
    def USDT_USD_FEED(cls):
        return _chainlink_feed("USDT_USD_FEED")

    @classmethod
    @property
    def MATIC_USD_FEED(cls):
        return _chainlink_feed("MATIC_USD_FEED")

    @classmethod
    @property
    def LINK_USD_FEED(cls):
        return _chainlink_feed("LINK_USD_FEED")

    @classmethod
    @property
    def AAVE_USD_FEED(cls):
        return _chainlink_feed("AAVE_USD_FEED")

    @classmethod
    @property
    def UNI_USD_FEED(cls):
        return _chainlink_feed("UNI_USD_FEED")

    @classmethod
    @property
    def TUSD_USD_FEED(cls):
        return _chainlink_feed("TUSD_USD_FEED")


_uniswap_pools = {
    1: {
        "USDC_ETH": "0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8",
        "ETH_CRV": "0x4c83A7f819A5c37D64B4c5A2f8238Ea082fA1f4e",
        "WBTC_USDC": "0x99ac8cA7087fA4A2A1FB6357269965A2014ABc35",
        "DAI_ETH": "0x60594a405d53811d3BC4766596EFD80fd545A270",
        "USDT_ETH": "0x4e68ccd3e89f51c3074ca5072bbac773960dfa36",
    },
    137: {
        "USDC_ETH": "0x0e44ceb592acfc5d3f09d996302eb4c499ff8c10",
        "WBTC_USDC": "0xfe343675878100b344802a6763fd373fdeed07a4",
        "USDT_ETH": "0x4ccd010148379ea531d6c587cfdd60180196f9b1",
        "WBTC_WETH": "0xfe343675878100b344802a6763fd373fdeed07a4",
        "WETH_DAI": "0x67a9fe12fa6082d9d0203c84c6c56d3c4b269f28",
        "MATIC_WETH": "0x167384319b41f7094e62f7506409eb38079abff8",
        "MATIC_USDC": "0x88f3c15523544835ff6c738ddb30995339ad57d6",
        "WETH_UNI": "0x357faf5843c7fd7fb4e34fbeabdac16eabe8a5bc",
        "MATIC_AAVE": "0xa9077cdb3d13f45b8b9d87c43e11bce0e73d8631",
        "LINK_WETH": "0x3e31ab7f37c048fc6574189135d108df80f0ea26",
        "TUSD_USDC": "0x39529e96c28807655b5856b3d342c6225111770e",
    },
}


def _get_uniswap_pool(name) -> str:
    chain_id = chain.id
    if chain_id == 1337:
        chain_id = 1
    if chain_id not in _token_addresses:
        raise ValueError(f"chain {chain_id} not supported")
    return _uniswap_pools[chain_id].get(name, ZERO_ADDRESS)


class UniswapPools:
    @classmethod
    @property
    def USDC_ETH(cls):
        return _get_uniswap_pool("USDC_ETH")

    @classmethod
    @property
    def ETH_CRV(cls):
        return _get_uniswap_pool("ETH_CRV")

    @classmethod
    @property
    def WBTC_USDC(cls):
        return _get_uniswap_pool("WBTC_USDC")

    @classmethod
    @property
    def DAI_ETH(cls):
        return _get_uniswap_pool("DAI_ETH")

    @classmethod
    @property
    def USDT_ETH(cls):
        return _get_uniswap_pool("USDT_ETH")

    @classmethod
    @property
    def WBTC_WETH(cls):
        return _get_uniswap_pool("WBTC_WETH")

    @classmethod
    @property
    def WETH_DAI(cls):
        return _get_uniswap_pool("WETH_DAI")

    @classmethod
    @property
    def MATIC_WETH(cls):
        return _get_uniswap_pool("MATIC_WETH")

    @classmethod
    @property
    def MATIC_USDC(cls):
        return _get_uniswap_pool("MATIC_USDC")

    @classmethod
    @property
    def WETH_UNI(cls):
        return _get_uniswap_pool("WETH_UNI")

    @classmethod
    @property
    def MATIC_AAVE(cls):
        return _get_uniswap_pool("MATIC_AAVE")

    @classmethod
    @property
    def LINK_WETH(cls):
        return _get_uniswap_pool("LINK_WETH")

    @classmethod
    @property
    def TUSD_USDC(cls):
        return _get_uniswap_pool("TUSD_USDC")

    @classmethod
    def all_pools(cls):
        return [
            pool
            for v in dir(cls)
            if not v.startswith("_")
            and v != "all_pools"
            and (pool := getattr(UniswapPools, v)) != ZERO_ADDRESS
        ]


def get_chainlink_feeds():
    if chain.id in (1, 1337):
        return [
            (TokenAddresses.ETH, ChainlinkFeeds.ETH_USD_FEED),
            (TokenAddresses.WETH, ChainlinkFeeds.ETH_USD_FEED),
            (TokenAddresses.DAI, ChainlinkFeeds.DAI_USD_FEED),
            (TokenAddresses.WBTC, ChainlinkFeeds.WBTC_USD_FEED),
            (TokenAddresses.CRV, ChainlinkFeeds.CRV_USD_FEED),
            (TokenAddresses.USDC, ChainlinkFeeds.USDC_USD_FEED),
            (TokenAddresses.USDT, ChainlinkFeeds.USDT_USD_FEED),
        ]
    if chain.id == 137:
        return [
            (TokenAddresses.ETH, ChainlinkFeeds.ETH_USD_FEED),
            (TokenAddresses.WETH, ChainlinkFeeds.ETH_USD_FEED),
            (TokenAddresses.DAI, ChainlinkFeeds.DAI_USD_FEED),
            (TokenAddresses.WBTC, ChainlinkFeeds.WBTC_USD_FEED),
            (TokenAddresses.USDC, ChainlinkFeeds.USDC_USD_FEED),
            (TokenAddresses.USDT, ChainlinkFeeds.USDT_USD_FEED),
            (TokenAddresses.WMATIC, ChainlinkFeeds.MATIC_USD_FEED),
            (TokenAddresses.LINK, ChainlinkFeeds.LINK_USD_FEED),
            (TokenAddresses.AAVE, ChainlinkFeeds.AAVE_USD_FEED),
            (TokenAddresses.UNI, ChainlinkFeeds.UNI_USD_FEED),
            (TokenAddresses.TUSD, ChainlinkFeeds.TUSD_USD_FEED),
        ]
    raise ValueError(f"chain {chain.id} not supported")


def is_stable(asset):
    return asset in [getattr(TokenAddresses, v) for v in STABLE_COINS]
