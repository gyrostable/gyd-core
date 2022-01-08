from decimal import Decimal
from tests.support.utils import scale

THETA_FLOOR: Decimal = scale("0.6", 18)
XU_MAX_REL: Decimal = scale("0.3", 18)  # Relative to ya. Scale by * ya.
ALPHA_MIN_REL: Decimal = scale("1", 18)  # Relative to ya. Scale by / ya.
