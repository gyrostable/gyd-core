// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./auth/GovernableUpgradeable.sol";

import "../interfaces/IGyroConfig.sol";
import "../interfaces/IGYDToken.sol";

import "../libraries/ConfigHelpers.sol";

contract GydToken is ERC20PermitUpgradeable, GovernableUpgradeable, IGYDToken {
    using EnumerableSet for EnumerableSet.AddressSet;
    using ConfigHelpers for IGyroConfig;

    EnumerableSet.AddressSet internal _minters;

    function initialize(
        address governor,
        string memory name,
        string memory symbol
    ) external initializer {
        __ERC20_init(name, symbol);
        __GovernableUpgradeable_initialize(governor);
    }

    function addMinter(address minter) external override governanceOnly {
        _minters.add(minter);
        emit MinterAdded(minter);
    }

    function removeMinter(address minter) external override governanceOnly {
        _minters.remove(minter);
        emit MinterRemoved(minter);
    }

    function listMinters() external view override returns (address[] memory) {
        return _minters.values();
    }

    function mint(address account, uint256 amount) external {
        require(_minters.contains(_msgSender()), Errors.NOT_AUTHORIZED);
        _mint(account, amount);
    }

    function burnFrom(address account, uint256 amount) external {
        uint256 currentAllowance = allowance(account, _msgSender());
        bool isMinter = _minters.contains(_msgSender());
        require(isMinter || currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        if (!isMinter) {
            _approve(account, _msgSender(), currentAllowance - amount);
        }
        _burn(account, amount);
    }

    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }
}
