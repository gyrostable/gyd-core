// SPDX-License-Identifier: for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>. 


pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Interface for the WETH token contract used internally for wrapping and unwrapping, to support
 * sending and receiving ETH in joins, swaps, and internal balance deposits and withdrawals.
 */
interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 amount) external;
}
