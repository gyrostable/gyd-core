// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "OpenZeppelin/openzeppelin-contracts@4.1.0/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.1.0/contracts/token/ERC20/IERC20.sol";

import "../../libraries/DataTypes.sol";
import "../../interfaces/IBalancerPoolRegistry.sol";
import "../../interfaces/ILPTokenExchanger.sol";

import "../../libraries/Errors.sol";
import "../../libraries/FixedPoint.sol";

import "../auth/Governable.sol";

interface IAsset {
    // solhint-disable-previous-line no-empty-blocks
}

interface BalancerVaultFactory {
    function joinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        JoinPoolRequest memory request
    ) external payable;

    function exitPool(
        bytes32 poolId,
        address sender,
        address payable recipient,
        ExitPoolRequest memory request
    ) external;

    struct JoinPoolRequest {
        IAsset[] assets;
        uint256[] maxAmountsIn;
        bytes userData;
        bool fromInternalBalance;
    }

    struct ExitPoolRequest {
        IAsset[] assets;
        uint256[] minAmountsOut;
        bytes userData;
        bool toInternalBalance;
    }
}

interface BalancerHelperFactory {
    function queryJoin(
        bytes32 poolId,
        address sender,
        address recipient,
        BalancerVaultFactory.JoinPoolRequest memory request
    ) external returns (uint256 bptOut, uint256[] memory amountsIn);

    function queryExit(
        bytes32 poolId,
        address sender,
        address recipient,
        BalancerVaultFactory.ExitPoolRequest memory request
    ) external returns (uint256 bptIn, uint256[] memory amountsOut);
}

/// @title Balancer token exchanger
abstract contract BalancerExchanger is ILPTokenExchanger {
    using FixedPoint for uint256;
    using SafeERC20 for IERC20;

    IBalancerPoolRegistry public poolRegistry;
    BalancerHelperFactory public balancerHelper;
    BalancerVaultFactory public balancerV2Vault;

    constructor(
        address _balancerV2Vault,
        address _balancerPoolRegistryAddress,
        address _balancerHelperAddress
    ) {
        balancerV2Vault = BalancerVaultFactory(_balancerV2Vault);
        balancerHelper = BalancerHelperFactory(_balancerHelperAddress);
        poolRegistry = IBalancerPoolRegistry(_balancerPoolRegistryAddress);
    }

    function getChosenBalancerPool(DataTypes.TokenTuple memory underlyingTokenTuple)
        internal
        returns (bytes32 poolId)
    {
        bytes32[] memory balancerPoolRegistry = poolRegistry.getPoolIds(
            underlyingTokenTuple.tokenAddress
        );

        /// Dummy logic to just return the first now. Change this.
        return balancerPoolRegistry[0];
    }

    function swapIn(DataTypes.TokenTuple memory underlyingTokenTuple)
        external
        override
        returns (uint256 bptTokens)
    {
        bool tokenTransferred = IERC20(underlyingTokenTuple.tokenAddress).transferFrom(
            msg.sender,
            address(this),
            underlyingTokenTuple.amount
        );
        require(tokenTransferred, "failed to transfer tokens from user to token exchanger");

        bytes32 poolId = getChosenBalancerPool(underlyingTokenTuple);

        IAsset[] memory assetsArray = new IAsset[](1);
        assetsArray[0] = IAsset(underlyingTokenTuple.tokenAddress);

        uint256[] memory maxAmountsIn = new uint256[](1);
        maxAmountsIn[0] = underlyingTokenTuple.amount;

        BalancerVaultFactory.JoinPoolRequest memory request = BalancerVaultFactory.JoinPoolRequest({
            assets: assetsArray,
            maxAmountsIn: maxAmountsIn,
            userData: "null",
            fromInternalBalance: false
        });

        (uint256 expectedBptOut, uint256[] memory expectedAmountsIn) = balancerHelper.queryJoin(
            poolId,
            address(this),
            msg.sender,
            request
        );

        balancerV2Vault.joinPool(poolId, address(this), msg.sender, request);

        return expectedBptOut;
    }

    function swapOut(DataTypes.TokenTuple memory tokenToWithdraw)
        external
        override
        returns (DataTypes.TokenTuple memory receivedToken)
    {
        bytes32 poolId = getChosenBalancerPool(tokenToWithdraw);

        IAsset[] memory assetsArray = new IAsset[](1);
        assetsArray[0] = IAsset(tokenToWithdraw.tokenAddress);

        uint256[] memory minAmountsOut = new uint256[](1);
        minAmountsOut[0] = tokenToWithdraw.amount;

        BalancerVaultFactory.ExitPoolRequest memory request = BalancerVaultFactory.ExitPoolRequest({
            assets: assetsArray,
            minAmountsOut: minAmountsOut,
            userData: "null",
            toInternalBalance: false
        });

        (uint256 expctedBptIn, uint256[] memory expectedAmountsOut) = balancerHelper.queryExit(
            poolId,
            address(this),
            msg.sender,
            request
        );

        balancerV2Vault.exitPool(poolId, address(this), payable(msg.sender), request);
    }
}
