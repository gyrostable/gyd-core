from decimal import Decimal

from tests.support.quantized_decimal import QuantizedDecimal
from tests.support.utils import scale

RAW_THETA_FLOOR = "0.6"
RAW_XU_MAX_REL = "0.3"
RAW_ALPHA_MIN_REL = "1"

THETA_FLOOR: Decimal = scale(RAW_THETA_FLOOR, 18)
XU_MAX_REL: Decimal = scale(RAW_XU_MAX_REL, 18)  # Relative to ya. Scale by * ya.
ALPHA_MIN_REL: Decimal = scale(RAW_ALPHA_MIN_REL, 18)  # Relative to ya. Scale by / ya.

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
BALANCER_POOL_ID_3 = (
    "0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000049"
)
BALANCER_POOL_ID_4 = (
    "0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000050"
)
BALANCER_POOL_ID_5 = (
    "0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000051"
)
BALANCER_VAULT_ADDRESS = "0xBA12222222228d8Ba445958a75a0704d566BF2C8"
MAX_ALLOWED_VAULT_DEVIATION = scale("0.05")
STABLECOIN_MAX_DEVIATION = scale("0.05")
MIN_TOKEN_PRICE = scale("1e-5")
