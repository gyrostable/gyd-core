// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../interfaces/IGyroConfig.sol";

import "../libraries/ConfigHelpers.sol";

contract GydToken is ERC20 {
    using ConfigHelpers for IGyroConfig;

    IGyroConfig public immutable gyroConfig;

    constructor(
        address _gyroConfig,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        require(_gyroConfig != address(0), Errors.INVALID_ARGUMENT);
        gyroConfig = IGyroConfig(_gyroConfig);
    }

    function mint(address account, uint256 amount) external {
        require(address(gyroConfig.getMotherboard()) == _msgSender(), Errors.NOT_AUTHORIZED);
        _mint(account, amount);
    }

    function burnFrom(address account, uint256 amount) external {
        uint256 currentAllowance = allowance(account, _msgSender());
        bool isMinter = address(gyroConfig.getMotherboard()) == _msgSender();
        require(isMinter || currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        if (!isMinter) {
            _approve(account, _msgSender(), currentAllowance - amount);
        }
        _burn(account, amount);
    }
}
