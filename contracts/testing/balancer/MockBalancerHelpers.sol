// SPDX-License-Identifier: for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>. 

pragma solidity ^0.8.4;

import "../../../libraries/FixedPoint.sol";
import "../../../interfaces/balancer/IAsset.sol";
import "../../../interfaces/balancer/IVault.sol";

/**
 * @dev This contract simply builds on top of the Balancer V2 architecture to provide useful helpers to users.
 * It connects different functionalities of the protocol components to allow accessing information that would
 * have required a more cumbersome setup if we wanted to provide these already built-in.
 */
contract MockBalancerHelpers {
    function queryJoin(
        bytes32, //poolId,
        address, // sender,
        address, // recipient,
        IVault.JoinPoolRequest memory request
    ) external pure returns (uint256 bptOut, uint256[] memory amountsIn) {
        bptOut = uint256(100e18);
        amountsIn = request.maxAmountsIn;

        return (bptOut, amountsIn);
    }

    function queryExit(
        bytes32, // poolId,
        address, // sender,
        address, // recipient,
        IVault.ExitPoolRequest memory request
    ) external pure returns (uint256 bptIn, uint256[] memory amountsOut) {
        bptIn = uint256(100e18);
        amountsOut = request.minAmountsOut;

        return (bptIn, amountsOut);
    }
}
