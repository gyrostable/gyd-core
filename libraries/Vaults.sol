// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

library Vaults {
    enum Type {
        GENERIC,
        BALANCER_CPMM,
        BALANCER_2CLP,
        BALANCER_3CLP,
        BALANCER_ECLP,
        // ECLPV2 is the ECLP version with optional rate scaling.
        // SOMEDAY when we're sure the old vault type won't be used anymore, we
        // can remove BALANCER_ECLP, the associated LP share price oracles, and
        // rename ECLPV2 to just ECLP.
        BALANCER_ECLPV2
    }
}
