// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../interfaces/ILPTokenExchangerRegistry.sol";
import "./auth/Governable.sol";
import "../libraries/Errors.sol";

contract LPTokenExchangerRegistry is ILPTokenExchangerRegistry, Governable {
    mapping(address => address) internal tokenExchangers;

    /// @inheritdoc ILPTokenExchangerRegistry
    function getTokenExchanger(address lpToken) external view override returns (ILPTokenExchanger) {
        address tokenExchangerAddress = tokenExchangers[lpToken];
        require(tokenExchangerAddress != address(0), Errors.EXCHANGER_NOT_FOUND);
        return ILPTokenExchanger(tokenExchangerAddress);
    }

    /// @inheritdoc ILPTokenExchangerRegistry
    function registerTokenExchanger(address lpToken, address lpTokenExchanger)
        external
        override
        governanceOnly
    {
        tokenExchangers[lpToken] = lpTokenExchanger;
    }

    /// @inheritdoc ILPTokenExchangerRegistry
    function deregisterTokenExchanger(address lpToken) external override governanceOnly {
        delete tokenExchangers[lpToken];
    }
}
