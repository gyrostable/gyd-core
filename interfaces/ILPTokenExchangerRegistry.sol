// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/// @notice A registry of LP token exchangers that allow to transform an arbitrary ERC-20
/// token into an LP token accepted by one of the vaults in Gyro
interface ILPTokenExchangerRegistry {
    /// @notice Finds the LP token exchanger to transform an underlying token in an LP
    /// token that is supported by the given `vault`
    /// @param lpToken the lpToken that will be deposited/withdrawn in/to the Gyroscope vault
    /// @return the address of the LP token exchanger to exchanger underlying tokens to/from the lp
    /// token supported by the vault
    function getTokenExchanger(address lpToken) external view returns (address);

    /// @notice Registers a new LP token exchanger to transform underlying tokens to/from
    /// lp tokens supported by a Gyroscope vault
    /// This will be called by governance when we want to support new vaults
    /// or new ways to deposit into them
    /// @param lpToken The LP token used by the Gyroscope Vault to register
    /// @param lpTokenExchanger address of the LP Token Exchanger contract that must follow the `ILPTokenExchanger` interface
    function registerTokenExchanger(address lpToken, address lpTokenExchanger)
        external;

    /// @notice Deregisters the LP token exchanger to transform underlying tokens to/from
    /// lp tokens supported by a Gyroscope vault
    /// This will be called by governance when we want to remove support for vaults
    /// @param lpToken The LP token used by the Gyroscope Vault to deregister
    function deregisterTokenExchanger(address lpToken) external;
}
