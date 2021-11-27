// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "OpenZeppelin/openzeppelin-contracts@4.3.2/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.3.2/contracts/token/ERC20/IERC20.sol";

import "../../libraries/DataTypes.sol";
import "../../interfaces/IBalancerPoolRegistry.sol";
import "../../interfaces/ILPTokenExchanger.sol";

import "../../libraries/Errors.sol";
import "../../libraries/FixedPoint.sol";

import "../auth/Governable.sol";

import "../../interfaces/balancer/interfaces/IVault.sol";
import "../../interfaces/balancer/interfaces/IAsset.sol";

interface BalancerHelperFactory {
    function queryJoin(
        bytes32 poolId,
        address sender,
        address recipient,
        IVault.JoinPoolRequest memory request
    ) external returns (uint256 bptOut, uint256[] memory amountsIn);

    function queryExit(
        bytes32 poolId,
        address sender,
        address recipient,
        IVault.ExitPoolRequest memory request
    ) external returns (uint256 bptIn, uint256[] memory amountsOut);
}

/// @title Balancer token exchanger
abstract contract BalancerExchanger is ILPTokenExchanger {
    using FixedPoint for uint256;
    using SafeERC20 for IERC20;

    IBalancerPoolRegistry public poolRegistry;
    BalancerHelperFactory public balancerHelper;
    IVault public balancerV2Vault;

    constructor(
        address _balancerV2Vault,
        address _balancerPoolRegistryAddress,
        address _balancerHelperAddress
    ) {
        balancerV2Vault = IVault(_balancerV2Vault);
        balancerHelper = BalancerHelperFactory(_balancerHelperAddress);
        poolRegistry = IBalancerPoolRegistry(_balancerPoolRegistryAddress);
    }

    function getChosenBalancerPool(
        DataTypes.MonetaryAmount memory underlyingMonetaryAmount
    ) internal returns (bytes32 poolId) {
        bytes32[] memory balancerPoolRegistry = poolRegistry.getPoolIds(
            underlyingMonetaryAmount.tokenAddress
        );

        /// Dummy logic to just return the first now. Change this.
        return balancerPoolRegistry[0];
    }

    function deposit(DataTypes.MonetaryAmount memory underlyingMonetaryAmount)
        external
        override
        returns (uint256)
    {
        bool tokenTransferred = IERC20(underlyingMonetaryAmount.tokenAddress)
            .transferFrom(
                msg.sender,
                address(this),
                underlyingMonetaryAmount.amount
            );
        require(
            tokenTransferred,
            "failed to transfer tokens from user to token exchanger"
        );

        bytes32 poolId = getChosenBalancerPool(underlyingMonetaryAmount);

        IAsset[] memory assetsArray = new IAsset[](1);
        assetsArray[0] = IAsset(underlyingMonetaryAmount.tokenAddress);

        uint256[] memory maxAmountsIn = new uint256[](1);
        maxAmountsIn[0] = underlyingMonetaryAmount.amount;

        IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest({
            assets: assetsArray,
            maxAmountsIn: maxAmountsIn,
            userData: "null",
            fromInternalBalance: false
        });

        (
            uint256 expectedBptOut,
            uint256[] memory expectedAmountsIn
        ) = balancerHelper.queryJoin(
                poolId,
                address(this),
                msg.sender,
                request
            );

        balancerV2Vault.joinPool(poolId, address(this), msg.sender, request);

        return expectedBptOut;
    }

    function withdraw(DataTypes.MonetaryAmount memory tokenToWithdraw)
        external
        override
        returns (uint256)
    {
        bytes32 poolId = getChosenBalancerPool(tokenToWithdraw);

        IAsset[] memory assetsArray = new IAsset[](1);
        assetsArray[0] = IAsset(tokenToWithdraw.tokenAddress);

        uint256[] memory minAmountsOut = new uint256[](1);
        minAmountsOut[0] = tokenToWithdraw.amount;

        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest({
            assets: assetsArray,
            minAmountsOut: minAmountsOut,
            userData: "null",
            toInternalBalance: false
        });

        (
            uint256 expectedBptIn,
            uint256[] memory expectedAmountsOut
        ) = balancerHelper.queryExit(
                poolId,
                address(this),
                msg.sender,
                request
            );

        balancerV2Vault.exitPool(
            poolId,
            address(this),
            payable(msg.sender),
            request
        );

        return expectedBptIn;
    }
}
