# Gyroscope V1

This repository contains the code for Gyroscope V1.

The documentation here is intended for contributors to this repository.

For the general Gyro documentation, please visit https://docs.gyro.finance

# Setup

Install Brownie as described [here](https://eth-brownie.readthedocs.io/en/stable/install.html).

# Tests

To run all tests in `/tests`, run `brownie test` from the project root.

# Licensing

Superluminal Labs Ltd. is the owner of this software and any accompanying files contained herein (collectively, this “Software”). This Software is not covered by the General Public License ("GPL") and does not confer any rights to the user thereunder. None of the code incorporated into the Software was GPL-licensed, and Superluminal Labs Ltd. has received prior custom licenses for all such code, including a special hybrid license between Superluminal Labs Ltd and Balancer Labs OÜ [Special Licence](./license/GyroscopeBalancerLicense.pdf).

# How vaults are kept balanced

The reserve is a set of vaults owned by the reserve.
Each vault owns tokens, for example, LP shares of an underlying CLP.
For each vault, a number of weights on the interval [0,1] are defined:

- `targetWeight`: the weight that governance would like the particular vault to have in the reserve
- `currentWeight`: the weight that the vault actually has in the reserve
- `resultingWeight`: an ephemeral weight used during `mint` and `redeem` operations that allows the safety checks to reason about what the state of the reserve would be were a proposed `mint` or `redeem` operation to take place.

Each calibration event (e.g., when adding a vault to the reserve) provides an opportunity to reset the `priceAtCalibration` and therefore change the `targetWeight` for a particular vault.
The price of the vault is expected to deviate from this `targetWeight` over time as the price of the vault tokens evolves.

During each `mint` and `redeem` operation, the safety checks ensure that the vault weight that would arise from the proposed operation is within some acceptable bounds.
These bounds are calculated as a multiplicative term of the `targetWeight` of the vault, set at the most recent calibration, and the `maxAllowedVaultDeviation`, set as a scaled percentage.

# How vault weight changes are effected

Each calibration event defines a new `targetWeight` for each vault.
However, for a vault that changes `targetWeight` between calibrations, the vault follows a ramping up/down schedule that linearly moves the `targetWeight` from the `weightAtPreviousCalibration` to the new `targetWeight`, according to a given `weightTransitionDuration`.
The motivation for this is to ensure a smooth transition between different weights in the reserve.

# What if a stablecoin in the reserve depegs?

In the Gyroscope system, each asset that is declared as a stablecoin in `AssetRegistry.sol` as a stablecoin has a floor and ceiling price around its peg.
By default this range is symmetric, with asset deviation `STABLECOIN_MAX_DEVIATION`, resulting in a floor price (e.g. 0.98) and a ceiling price (e.g. 0.98).
The system supports custom ranges per asset for a stablecoin that, for instance, is often depegged to the upside but rarely to the downside.

A stablecoin is considered depegged if it is outside of the interval [`floor`, `ceiling`].

## Case I: a reserve asset stablecoin is above peg.

    Minting: allowed.

When the USD value of the input basket is calculated, any above peg stablecoin is computed using the lower bound USD price, that is, the stablecoin is priced at 1 USD (rather than the actual price >1 USD). This is piped into the PAMM.

The result: anyone minting with an input basket containing above peg stablecoins will receive a lower than market price for their stablecoins in GYD.

    Redeeming: allowed.

When the amount to redeem is calculated in terms of USD, the lower bound is taken. Above peg stablecoins are priced at 1 USD. This value is piped into the PAMM. When the redeem order is created, the upper bound USD prices are used for the USD price, such that the price used is the above peg stablecoin price.

The result: anyone redeeming for above peg stablecoins receives fewer than 1:1 units of the output stablecoin.

## Case II: a reserve asset stablecoin is below peg.

    Minting: not allowed.

The Gyroscope reserve should not grow its holdings of stablecoins below peg.

    Redeeming: allowed.

When the amount to redeem is calculated in terms of USD, the lower bound is taken. The reserve is priced at true USD value (using the below peg values), and this is piped into the PAMM. When the redeem order is created, upper bound USD prices are used for individual vault tokens, so a below peg stablecoin is priced instead at 1USD.

The result: anyone redeeming for a below peg stablecoin receives a better price for their output stablecoin than the true price.

# Safety checks performed for a `mint` operation

1. Check whether all vaults are using prices that are large enough (preventing an attack vector with dust-like prices), otherwise mint fails.
2. Check on the vault balance safety. This means either all the vaults would be sufficiently close to the target weights OR that a vault outside the accepted deviation is being rebalanced towards the target weight. If either of these conditions is true, balance safety is true.
3. Check whether EITHER: A. All stablecoins in all vaults are on peg (in the sense defined above) OR B. Any depegged stablecoin is above its floor price OR C. The result of the mint operation is that the vault weight falls.
4. If one of (A-C) is true, and the balance safety is true, then the mint can take place.

# Safety checks performed for a `redeem` operation

1. Check whether all vaults are using prices that are large enough (preventing an attack vector with dust-like prices), otherwise redeem fails.
2. Check whether either: (A) all of the vaults resulting from the redeem operation would be sufficiently close to the target weights OR (B) that a vault outside the accepted deviation is being rebalanced towards the target weight.
3. If one of (A) or (B) is true, then the redeem can take place.
