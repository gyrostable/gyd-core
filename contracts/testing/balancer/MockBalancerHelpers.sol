// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

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
        bytes32 poolId,
        address sender,
        address recipient,
        IVault.JoinPoolRequest memory request
    ) external returns (uint256 bptOut, uint256[] memory amountsIn) {
        bptOut = uint256(100e18);
        amountsIn = request.maxAmountsIn;

        return (bptOut, amountsIn);
    }

    function queryExit(
        bytes32 poolId,
        address sender,
        address recipient,
        IVault.ExitPoolRequest memory request
    ) external returns (uint256 bptIn, uint256[] memory amountsOut) {
        bptIn = uint256(100e18);
        amountsOut = request.minAmountsOut;

        return (bptIn, amountsOut);
    }
}
