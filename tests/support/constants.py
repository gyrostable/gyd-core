from decimal import Decimal

from tests.support.quantized_decimal import QuantizedDecimal
from tests.support.utils import scale

RAW_THETA_FLOOR = "0.6"
RAW_XU_MAX_REL = "0.3"
RAW_ALPHA_MIN_REL = "1"

THETA_FLOOR: Decimal = scale(RAW_THETA_FLOOR, 18)
XU_MAX_REL: Decimal = scale(RAW_XU_MAX_REL, 18)  # Relative to ya. Scale by * ya.
ALPHA_MIN_REL: Decimal = scale(RAW_ALPHA_MIN_REL, 18)  # Relative to ya. Scale by / ya.
OUTFLOW_MEMORY: Decimal = Decimal(999993123563518195)

UNSCALED_THETA_FLOOR = QuantizedDecimal(RAW_THETA_FLOOR)
UNSCALED_XU_MAX_REL = QuantizedDecimal(RAW_XU_MAX_REL)
UNSCALED_ALPHA_MIN_REL = QuantizedDecimal(RAW_ALPHA_MIN_REL)

COINBASE_SIGNING_ADDRESS = "0xfCEAdAFab14d46e20144F48824d0C09B1a03F2BC"

WBTC_ADDRESS = "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599"
DAI_ADDRESS = "0x6B175474E89094C44Da98b954EedeAC495271d0F"
USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"

BALANCER_POOL_ID = "0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080"
BALANCER_POOL_ID_2 = (
    "0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000088"
)
BALANCER_VAULT_ADDRESS = "0xBA12222222228d8Ba445958a75a0704d566BF2C8"

MAX_ALLOWED_VAULT_DEVIATION = scale("0.05")

STABLECOIN_MAX_DEVIATION = scale("0.05")
MIN_TOKEN_PRICE = scale("1e-5")

RESERVE_VAULTS = 10

UNISWAP_ROUTER = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"
SUSHISWAP_ROUTER = "0xd9e1ce17f2641f24ae83637ab66a2cca9c378b9f"


# deployed from the uniswap-oracle repo
UNISWAP_V3_ORACLE = "0xfE5d9082B689D239c264001B2a5dBf9fC3E7d6b0"

BALANCER_POOL_IDS = {
    "WETH_DAI": "0x0b09dea16768f0799065c475be02919503cb2a3500020000000000000000001a",
    "DAI_USDC_USDT": "0x06df3b2bbb68adc8b0e302443692037ed9f91b42000000000000000000000063",
    "WBTC_WETH": "0xa6f548df93de924d73be7d25dc02554c6bd66db500020000000000000000000e",
    "WETH_USDC": "0x96646936b91d6b9d7d0c47c496afbf3d6ec7b6f8000200000000000000000019",
}


def address_from_pool_id(pool_id):
    return pool_id[:42]


SAFETY_BLOCKS_AUTOMATIC = 1_800  # ~1 hour on Polygon
SAFETY_BLOCKS_GUARDIAN = 5_400  # ~3 hours on Polygon


GYD_GLOBAL_SUPPLY_CAP = scale(100_000)
GYD_AUTHENTICATED_USER_CAP = scale(20_000)
GYD_USER_CAP = scale(10)
