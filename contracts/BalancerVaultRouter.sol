// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../libraries/DataTypes.sol";
import "../interfaces/IVaultRouter.sol";
import "../interfaces/IVault.sol";
import "../interfaces/ILPTokenExchangerRegistry.sol";
import "../interfaces/ILPTokenExchanger.sol";
import "./BaseVaultRouter.sol";

/// @title Subclass of BaseVaultRouter to manage Balancer Vaults
abstract contract BalancerVaultRouter is BaseVaultRouter {

}
