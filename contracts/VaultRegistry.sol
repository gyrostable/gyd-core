// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../interfaces/IVaultRegistry.sol";
import "./auth/Governable.sol";

contract VaultRegistry is IVaultRegistry, Governable {}
