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

interface BalancerV2Factory {
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

/// @title Balancer token exchanger
abstract contract BalancerExchanger is ILPTokenExchanger {
    using FixedPoint for uint256;
    using SafeERC20 for IERC20;

    address private BalancerV2VaultAddress;

    IBalancerPoolRegistry public poolRegistry;

    constructor(address _BalancerV2Vault, address _balancerPoolRegistryAddress) {
        BalancerV2VaultAddress = _BalancerV2Vault;
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

    function swapIn(DataTypes.TokenTuple memory underlyingTokenTuple) external override {
        bool tokenTransferred = IERC20(underlyingTokenTuple.tokenAddress).transferFrom(
            msg.sender,
            address(this),
            underlyingTokenTuple.amount
        );
        require(tokenTransferred, "failed to transfer tokens from user to token exchanger");

        BalancerV2Factory balancerV2Vault = BalancerV2Factory(BalancerV2VaultAddress);

        bytes32 poolId = getChosenBalancerPool(underlyingTokenTuple);

        IAsset[] memory assetsArray = new IAsset[](1);
        assetsArray[0] = IAsset(underlyingTokenTuple.tokenAddress);

        uint256[] memory maxAmountsIn = new uint256[](1);
        maxAmountsIn[0] = underlyingTokenTuple.amount;

        BalancerV2Factory.JoinPoolRequest memory request = BalancerV2Factory.JoinPoolRequest({
            assets: assetsArray,
            maxAmountsIn: maxAmountsIn,
            userData: "null",
            fromInternalBalance: false
        });

        balancerV2Vault.joinPool(poolId, address(this), msg.sender, request);
    }

    function swapOut(DataTypes.TokenTuple memory underlyingTokenTuple) external override {
        BalancerV2Factory balancerV2Vault = BalancerV2Factory(BalancerV2VaultAddress);

        bytes32 poolId = getChosenBalancerPool(underlyingTokenTuple);

        IAsset[] memory assetsArray = new IAsset[](1);
        assetsArray[0] = IAsset(underlyingTokenTuple.tokenAddress);

        uint256[] memory minAmountsOut = new uint256[](1);
        minAmountsOut[0] = underlyingTokenTuple.amount;

        BalancerV2Factory.ExitPoolRequest memory request = BalancerV2Factory.ExitPoolRequest({
            assets: assetsArray,
            minAmountsOut: minAmountsOut,
            userData: "null",
            toInternalBalance: false
        });

        balancerV2Vault.exitPool(poolId, address(this), payable(msg.sender), request);
    }
}
