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

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../../interfaces/balancer/IVault.sol";
import "../../../interfaces/balancer/IBasePool.sol";
import "../../../interfaces/balancer/IPoolSwapStructs.sol";
import "../../../interfaces/balancer/IMinimalSwapInfoPool.sol";

contract MockBalVault is IPoolSwapStructs {
    struct Pool {
        IERC20[] tokens;
        uint256[] balances;
        address poolAddress;
    }

    mapping(bytes32 => Pool) private vaultPools;

    uint256 public lastChangeBlock;
    uint256 public cash;

    function setPoolTokens(
        bytes32 poolId,
        IERC20[] memory tokens,
        uint256[] memory balances
    ) external {
        address poolAddress = vaultPools[poolId].poolAddress;
        Pool memory newPool = Pool(tokens, balances, poolAddress);
        vaultPools[poolId] = newPool;
    }

    function getPoolTokens(bytes32 poolId)
        external
        view
        returns (
            IERC20[] memory,
            uint256[] memory,
            uint256
        )
    {
        Pool storage pool = vaultPools[poolId];
        IERC20[] memory tokens = new IERC20[](pool.tokens.length);
        uint256[] memory balances = new uint256[](pool.tokens.length);

        for (uint256 i = 0; i < pool.tokens.length; i++) {
            tokens[i] = pool.tokens[i];
            balances[i] = pool.balances[i];
        }

        return (tokens, balances, lastChangeBlock);
    }

    function registerPool(IVault.PoolSpecialization) external view returns (bytes32) {
        // solhint-disable-previous-line no-empty-blocks
    }

    function registerTokens(
        bytes32 poolId,
        IERC20[] memory tokens,
        address[] memory
    ) external {
        Pool storage pool = vaultPools[poolId];
        for (uint256 i = 0; i < tokens.length; i++) {
            pool.tokens.push(tokens[i]);
        }
    }

    function setLastChangeBlock(uint256 _lastChangeBlock) external {
        lastChangeBlock = _lastChangeBlock;
    }

    function setCash(uint256 _newCash) external {
        cash = _newCash;
    }

    function getPoolTokenInfo(bytes32 poolId, address token)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            address
        )
    {
        address assetManager = 0x0000000000000000000000000000000000000000;
        return (cash, 0, lastChangeBlock, assetManager);
    }

    function storePoolAddress(bytes32 poolId, address _mockBalancerPoolAddress) external {
        vaultPools[poolId].poolAddress = _mockBalancerPoolAddress;
    }

    function getPool(bytes32 poolId) external view returns (address, IVault.PoolSpecialization) {
        return (vaultPools[poolId].poolAddress, IVault.PoolSpecialization.GENERAL);
    }
}
