// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/// @notice IGYDToken is the GYD token contract
interface IGYDToken is IERC20Upgradeable {
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);

    /// @notice Adds an address allowed to mint new GYD tokens
    /// @param _minter the address of the authorized minter
    function addMinter(address _minter) external;

    /// @notice Removes an address allowed to mint new GYD tokens
    /// @param _minter the address of the authorized minter
    function removeMinter(address _minter) external;

    /// @return the addresses of the authorized minters
    function listMinters() external returns (address[] memory);

    /// @notice Mints `amount` of GYD token for `account`
    function mint(address account, uint256 amount) external;

    /// @notice Burns `amount` of GYD token
    function burn(uint256 amount) external;

    /// @notice Burns `amount` of GYD token from `account`
    function burnFrom(address account, uint256 amount) external;

    /// @notice Supply preminted for bootstrapping.
    function bootstrappingSupply() view external returns (uint256);

    /// @notice Total Supply except for the GYD that have been preminted for bootstrapping.
    function actualSupply() view external returns (uint256);

    /// @notice Like mint(account, amount) but account for as bootstrapping supply.
    /// Intended to be used only ~once, at system bootstrapping.
    function mintBootstrapping(address account, uint256 amount) external;

    /// @notice Like burn(amount) but account for as bootstrapping supply.
    function burnBootstrapping(uint256 amount) external;
}
