
from brownie import *
from brownie.exceptions import VirtualMachineError
from tests.support.types import PammParams
from tests.support.utils import scale, to_decimal as D, unscale
from tests.support.trace_analyzer import Tracer

import tests.support.pamm as pypamm

from brownie import TestingPAMMV1, GyroConfig

# ALPHA_MIN_REL_U = D("2.0")
# XU_MAX_REL_U = D("0.5")
# THETA_FLOOR_U = D("0.8")
# OUTFLOW_MEMORY = D(999993123563518195)  # Unused here.
#
# BA_U = D("0.9")
# YA_U = D(1)
# X_U = D("0.4084084084084084")

THETA_FLOOR_U = D("0.8")
XU_MAX_REL_U = D("0.5")
ALPHA_MIN_REL_U = D("2.0")
OUTFLOW_MEMORY = D(999993123563518195)  # Unused here.

X_U = D("0.1")
BA_U = D("0.75")
YA_U = D(1)

# tracer = Tracer.load()

def main():
    admin = accounts[0]

    gyro_config = admin.deploy(GyroConfig)
    gyro_config.initialize(admin)

    params_s = PammParams(
        int(scale(ALPHA_MIN_REL_U)),
        int(scale(XU_MAX_REL_U)),
        int(scale(THETA_FLOOR_U)),
        int(OUTFLOW_MEMORY),
    )
    pamm = TestingPAMMV1.deploy(
        admin,
        gyro_config,
        params_s,
        {"from": admin},
    )

    pyparams = pypamm.Params(ALPHA_MIN_REL_U, XU_MAX_REL_U, THETA_FLOOR_U)

    if (BA_U/YA_U < THETA_FLOOR_U):
        print("Anchor reserve ratio <= theta_bar. This calculation is ill-defined. Exiting.")
        return

    alphahat_python = pypamm.compute_slope_unconstrained(BA_U, YA_U, THETA_FLOOR_U)
    alpha_python = pypamm.compute_slope(BA_U, YA_U, THETA_FLOOR_U, ALPHA_MIN_REL_U)
    xuhat_python = pypamm.compute_upper_redemption_threshold_unconstrained(BA_U, YA_U, alpha_python, 1 - THETA_FLOOR_U)
    xu_python = pypamm.compute_upper_redemption_threshold(BA_U, YA_U, alpha_python,
        XU_MAX_REL_U, 1 - THETA_FLOOR_U)
    xl_python = pypamm.compute_lower_redemption_threshold(BA_U, YA_U, alpha_python, xu_python)
    print("derived values (python):")
    print(dict(alpha=alpha_python, xu=xu_python, xl=xl_python, alphahat=alphahat_python,
               xuhat=xuhat_python))
    print(dict(x=X_U))
    print(pyparams)
    print()

    b_python = pypamm.compute_reserve(X_U, BA_U, YA_U, pyparams)
    pamm_python = pypamm.Pamm(pyparams)
    pamm_python.update_state(X_U, b_python, YA_U - X_U)
    ba_reconstructed_python = pamm_python.compute_anchor_reserve_value()
    reg_reconstructed_python = pamm_python._compute_current_region_ext()
    print("computed values (python):")
    print(dict(b=b_python, r=b_python/(YA_U-X_U), ba=ba_reconstructed_python, reg_reconstructed=reg_reconstructed_python))
    print()

    state = (scale(X_U), scale(BA_U), scale(YA_U))

    alpha_solidity = unscale(pamm.computeAlpha(scale(BA_U), scale(YA_U), scale(THETA_FLOOR_U),
                                       scale(ALPHA_MIN_REL_U)))
    xu_solidity = unscale(pamm.computeXu(scale(BA_U), scale(YA_U), scale(alpha_solidity),
                                         scale(XU_MAX_REL_U), scale(1-THETA_FLOOR_U)))
    xl_solidity = unscale(pamm.computeXl(*scale([BA_U, YA_U, alpha_solidity, xu_solidity]), False))
    print("solidity:")
    print(dict(alpha=alpha_solidity, xu=xu_solidity, xl=xl_solidity))
    print()

    print("region:")
    reg_python = pypamm.compute_region_ext(X_U, BA_U, YA_U, pyparams)
    reg_solidity = pamm.computeRegion(state).return_value
    print(f"python direct: {reg_python}")# = {reg_python.value}")
    print(f"solidity reconstructed: {reg_solidity}")
    print()

    print("--- Solidity consistency check ---")
    b_solidity = unscale(pamm.computeReserveFixedParams(*scale([X_U, BA_U, YA_U, alpha_solidity, xu_solidity, xl_solidity])))
    b_live_solidity = unscale(pamm.computeReserve(*scale([X_U, BA_U, YA_U]), params_s))
    derived_s = pamm.computeDerivedParams()
    state_x_s = (scale(X_U), scale(b_solidity), scale(YA_U - X_U))
    ba_reconstructed_solidity = unscale(pamm.computeAnchoredReserveValue(state_x_s, params_s, derived_s))
    b2 = unscale(pamm.computeReserve(*scale([X_U, ba_reconstructed_solidity, YA_U]), params_s))
    print(dict(b=b_solidity, ba=ba_reconstructed_solidity, b_live=b_live_solidity, b2=b2))

    # TODO WIP:
    # - What python says is totally fine: When it's region iii, we *shouldn't* try to reconstruct ba and we also don't have to b/c we know that the price is gonna be = reserve ratio.
    # - Solidity kinda also says this. Check it's used correctly & then maybe comment.
    # - Actually it's a bit funky: CASE_I_iii *does* reconstruct a ba value, which can however be wrong, but the resulting calculation is correct AFAICT. That's a bit wild really.
    # - The python version refuses to give any other info for iii, and it doesn't have to either.
    # - The region is still plain wrong and used in a wrong way, that's concerning.
    # * Why do we do any complicated calcs for region I_iii anyways? Why not just use the current reserve ratio for redemptions? Are python and solidity different here? Compare!
    # ~ Perhaps the region in Solidity should be CASE_iii, not CASE_I_iii?
    # ~ We probably want clean regression tests very soon!

# This crashes due to a bug in Tracer :(
# try:
#     pamm.computeDerivedParamsTx()
# except VirtualMachineError:
#     tracer.trace_tx(history[-1])

