// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./auth/Governable.sol";
import "../interfaces/ILPTokenExchangerRegistry.sol";

contract LPTokenExchangerRegistry is ILPTokenExchangerRegistry, Governable {
    mapping(address => address) private tokenExchangers;

    function getTokenExchanger(address lpToken)
        external
        view
        override
        returns (address)
    {
        return tokenExchangers[lpToken];
    }

    function registerTokenExchanger(address lpToken, address lpTokenExchanger)
        external
        override
        governanceOnly
    {
        tokenExchangers[lpToken] = lpTokenExchanger;
    }

    function deregisterTokenExchanger(address lpToken)
        external
        override
        governanceOnly
    {
        delete tokenExchangers[lpToken];
    }
}
