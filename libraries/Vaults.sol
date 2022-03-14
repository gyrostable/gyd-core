// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

library Vaults {
    enum Type {
        GENERIC,
        BALANCER_CPMM,
        BALANCER_CPMMV2,
        BALANCER_CPMMV3,
        BALANCER_CEMM
    }
}
