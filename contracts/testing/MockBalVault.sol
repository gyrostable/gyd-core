// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

interface IAsset {
    // solhint-disable-previous-line no-empty-blocks
}

contract MockBalVault {
    // function getAuthorizer() external view returns (IAuthorizer);

    // function setAuthorizer(IAuthorizer newAuthorizer) external;

    // event AuthorizerChanged(IAuthorizer indexed newAuthorizer);

    // function hasApprovedRelayer(address user, address relayer) external view returns (bool);

    // function setRelayerApproval(
    //     address sender,
    //     address relayer,
    //     bool approved
    // ) external;

    // event RelayerApprovalChanged(address indexed relayer, address indexed sender, bool approved);

    // function getInternalBalance(address user, IERC20[] memory tokens)
    //     external
    //     view
    //     returns (uint256[] memory);

    // function manageUserBalance(UserBalanceOp[] memory ops) external payable;

    // struct UserBalanceOp {
    //     UserBalanceOpKind kind;
    //     IAsset asset;
    //     uint256 amount;
    //     address sender;
    //     address payable recipient;
    // }

    // enum UserBalanceOpKind {
    //     DEPOSIT_INTERNAL,
    //     WITHDRAW_INTERNAL,
    //     TRANSFER_INTERNAL,
    //     TRANSFER_EXTERNAL
    // }

    // event InternalBalanceChanged(address indexed user, IERC20 indexed token, int256 delta);

    // event ExternalBalanceTransfer(
    //     IERC20 indexed token,
    //     address indexed sender,
    //     address recipient,
    //     uint256 amount
    // );

    // enum PoolSpecialization {
    //     GENERAL,
    //     MINIMAL_SWAP_INFO,
    //     TWO_TOKEN
    // }

    // function registerPool(PoolSpecialization specialization) external returns (bytes32);

    // event PoolRegistered(
    //     bytes32 indexed poolId,
    //     address indexed poolAddress,
    //     PoolSpecialization specialization
    // );

    // function getPool(bytes32 poolId) external view returns (address, PoolSpecialization);

    // function registerTokens(
    //     bytes32 poolId,
    //     IERC20[] memory tokens,
    //     address[] memory assetManagers
    // ) external;

    // event TokensRegistered(bytes32 indexed poolId, IERC20[] tokens, address[] assetManagers);

    // function deregisterTokens(bytes32 poolId, IERC20[] memory tokens) external;

    // event TokensDeregistered(bytes32 indexed poolId, IERC20[] tokens);

    // function getPoolTokenInfo(bytes32 poolId, IERC20 token)
    //     external
    //     view
    //     returns (
    //         uint256 cash,
    //         uint256 managed,
    //         uint256 lastChangeBlock,
    //         address assetManager
    //     );

    // function getPoolTokens(bytes32 poolId)
    //     external
    //     view
    //     returns (
    //         IERC20[] memory tokens,
    //         uint256[] memory balances,
    //         uint256 lastChangeBlock
    //     );

    function joinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        JoinPoolRequest memory request
    ) external payable {}

    struct JoinPoolRequest {
        IAsset[] assets;
        uint256[] maxAmountsIn;
        bytes userData;
        bool fromInternalBalance;
    }

    function exitPool(
        bytes32 poolId,
        address sender,
        address payable recipient,
        ExitPoolRequest memory request
    ) external {}

    struct ExitPoolRequest {
        IAsset[] assets;
        uint256[] minAmountsOut;
        bytes userData;
        bool toInternalBalance;
    }

    // event PoolBalanceChanged(
    //     bytes32 indexed poolId,
    //     address indexed liquidityProvider,
    //     IERC20[] tokens,
    //     int256[] deltas,
    //     uint256[] protocolFeeAmounts
    // );

    enum PoolBalanceChangeKind {
        JOIN,
        EXIT
    }

    // enum SwapKind {
    //     GIVEN_IN,
    //     GIVEN_OUT
    // }

    // function swap(
    //     SingleSwap memory singleSwap,
    //     FundManagement memory funds,
    //     uint256 limit,
    //     uint256 deadline
    // ) external payable returns (uint256);

    // struct SingleSwap {
    //     bytes32 poolId;
    //     SwapKind kind;
    //     IAsset assetIn;
    //     IAsset assetOut;
    //     uint256 amount;
    //     bytes userData;
    // }

    // function batchSwap(
    //     SwapKind kind,
    //     BatchSwapStep[] memory swaps,
    //     IAsset[] memory assets,
    //     FundManagement memory funds,
    //     int256[] memory limits,
    //     uint256 deadline
    // ) external payable returns (int256[] memory);

    // struct BatchSwapStep {
    //     bytes32 poolId;
    //     uint256 assetInIndex;
    //     uint256 assetOutIndex;
    //     uint256 amount;
    //     bytes userData;
    // }

    // event Swap(
    //     bytes32 indexed poolId,
    //     IERC20 indexed tokenIn,
    //     IERC20 indexed tokenOut,
    //     uint256 amountIn,
    //     uint256 amountOut
    // );

    // struct FundManagement {
    //     address sender;
    //     bool fromInternalBalance;
    //     address payable recipient;
    //     bool toInternalBalance;
    // }

    // function queryBatchSwap(
    //     SwapKind kind,
    //     BatchSwapStep[] memory swaps,
    //     IAsset[] memory assets,
    //     FundManagement memory funds
    // ) external returns (int256[] memory assetDeltas);

    // function flashLoan(
    //     IFlashLoanRecipient recipient,
    //     IERC20[] memory tokens,
    //     uint256[] memory amounts,
    //     bytes memory userData
    // ) external;

    // event FlashLoan(
    //     IFlashLoanRecipient indexed recipient,
    //     IERC20 indexed token,
    //     uint256 amount,
    //     uint256 feeAmount
    // );

    // function managePoolBalance(PoolBalanceOp[] memory ops) external;

    // struct PoolBalanceOp {
    //     PoolBalanceOpKind kind;
    //     bytes32 poolId;
    //     IERC20 token;
    //     uint256 amount;
    // }

    // enum PoolBalanceOpKind {
    //     WITHDRAW,
    //     DEPOSIT,
    //     UPDATE
    // }

    // event PoolBalanceManaged(
    //     bytes32 indexed poolId,
    //     address indexed assetManager,
    //     IERC20 indexed token,
    //     int256 cashDelta,
    //     int256 managedDelta
    // );

    // function getProtocolFeesCollector() external view returns (IProtocolFeesCollector);

    // function setPaused(bool paused) external;

    // function WETH() external view returns (IWETH);
    // // solhint-disable-previous-line func-name-mixedcase
}
