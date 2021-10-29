// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "OpenZeppelin/openzeppelin-contracts@4.3.2/contracts/token/ERC20/IERC20.sol";

/// @notice IGYDToken is the GYD token contract
interface IGYDToken is IERC20 {
    /// @notice Set the address allowed to mint new GYD tokens
    /// @dev This should typically be the motherboard that will mint or burn GYD tokens
    /// when user interact with it
    /// @param _minter the address of the authorized minter
    function setMinter(address _minter) external;

    /// @notice Gets the address for the minter contract
    /// @return the address of the minter contract
    function minter() external returns (address);

    /// @notice Mints `amount` of GYD token
    function mint(uint256 amount) external;

    /// @notice Mints `amount` of GYD token on behalf of `account`
    function mintFor(uint256 amount, address account) external;
}
