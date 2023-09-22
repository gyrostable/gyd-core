// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../contracts/GyroConfig.sol";

library GyroConfigVaultKeys {
    bytes32 public constant PROTOCOL_SWAP_FEE_PERC_KEY = "PROTOCOL_SWAP_FEE_PERC";
    bytes32 public constant PROTOCOL_FEE_GYRO_PORTION_KEY = "PROTOCOL_FEE_GYRO_PORTION";
    bytes32 public constant GYRO_TREASURY_KEY = "GYRO_TREASURY";
    bytes32 public constant BAL_TREASURY_KEY = "BAL_TREASURY";
}

library GyroConfigHelpers {
    function getSwapFeePercForPool(
        IGyroConfig gyroConfig,
        address poolAddress,
        bytes32 poolType
    ) internal view returns (uint256) {
        return
            _getPoolSetting(
                gyroConfig,
                GyroConfigVaultKeys.PROTOCOL_SWAP_FEE_PERC_KEY,
                poolType,
                poolAddress
            );
    }

    function getProtocolFeeGyroPortionForPool(
        IGyroConfig gyroConfig,
        address poolAddress,
        bytes32 poolType
    ) internal view returns (uint256) {
        return
            _getPoolSetting(
                gyroConfig,
                GyroConfigVaultKeys.PROTOCOL_FEE_GYRO_PORTION_KEY,
                poolType,
                poolAddress
            );
    }

    function _getPoolSetting(
        IGyroConfig gyroConfig,
        bytes32 globalKey,
        bytes32 poolType,
        address poolAddress
    ) internal view returns (uint256) {
        bytes32 poolSpecificKey = keccak256(abi.encode(globalKey, poolAddress));

        // Fetch the key. To do this we first check for a pool-specific fee,
        // and if not present, use the pool-type key.
        // Failing that we fall back to the global setting.
        if (gyroConfig.hasKey(poolSpecificKey)) {
            return gyroConfig.getUint(poolSpecificKey);
        }

        bytes32 poolTypeKey = keccak256(abi.encodePacked(globalKey, poolType));
        if (gyroConfig.hasKey(poolTypeKey)) {
            return gyroConfig.getUint(poolTypeKey);
        }

        return gyroConfig.getUint(globalKey);
    }
}

contract DeployedConfigTest is Test {
    using GyroConfigHelpers for GyroConfig;

    GyroConfig public config;

    address public constant MAINNET_CONFIG = 0xaC89cc9d78BBAd7EB3a02601B4D65dAa1f908aA6;
    address public constant BAL_TREASURY = 0xce88686553686DA562CE7Cea497CE749DA109f9F;

    address public constant WSETH_WETH_POOL = 0xf01b0684C98CD7aDA480BFDF6e43876422fa1Fc1;
    address public constant WSETH_CBETH_POOL = 0xF7A826D47c8E02835D94fb0Aa40F0cC9505cb134;
    address public constant R_SUSD_POOL = 0x52b69d6b3eB0BD6b2b4A48a316Dfb0e1460E67E4;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("RPC"));
        config = GyroConfig(MAINNET_CONFIG);
    }

    function testConfig() public {
        assertEq(config.getAddress(GyroConfigVaultKeys.BAL_TREASURY_KEY), BAL_TREASURY);
        assertEq(config.getSwapFeePercForPool(WSETH_WETH_POOL, "ECLP"), 5e17);
        assertEq(config.getSwapFeePercForPool(WSETH_CBETH_POOL, "ECLP"), 5e17);
        assertEq(config.getSwapFeePercForPool(R_SUSD_POOL, "ECLP"), 5e17);
    }
}
