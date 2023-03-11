// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../libraries/DecimalScale.sol";
import "../../libraries/FixedPoint.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";
import {ConfigKeys} from "../../libraries/ConfigKeys.sol";

import {Motherboard} from "../../contracts/Motherboard.sol";
import {GyroConfig} from "../../contracts/GyroConfig.sol";
import {GydToken} from "../../contracts/GydToken.sol";
import {TestingReserveSafetyManager} from "../../contracts/testing/TestingReserveSafetyManager.sol";
import {MockGyroVault} from "../../contracts/testing/MockGyroVault.sol";

contract DryMint is Test {
    using FixedPoint for uint256;
    using DecimalScale for uint256;

    GyroConfig internal gyroConfig;
    Motherboard internal motherboard;
    GydToken internal gydToken;
    MockReserveManager internal mockReserveManager = new MockReserveManager();
    MockFeeHandler internal feeHandler = new MockFeeHandler();
    MockPAMMV1 internal mockPAMMv1 = new MockPAMMV1();

    TestingReserveSafetyManager internal reserveSafetyManager;

    address public constant governorAddress = address(0);
    uint256 internal _maxAllowedVaultDeviation = 3e17;
    uint256 internal _stablecoinMaxDeviation = 5e16;
    uint256 internal _minTokenPrice = 1e14;

    address[] addresses = createAddresses(100);

    address internal userAddress = addresses[99];

    function setUp() public virtual {
        gyroConfig = new GyroConfig();
        gyroConfig.initialize(address(this));
        gydToken = new GydToken(address(gyroConfig));
        gyroConfig.setAddress(ConfigKeys.GYD_TOKEN_ADDRESS, address(gydToken));
        gyroConfig.setAddress(ConfigKeys.RESERVE_ADDRESS, addresses[0]);
        gyroConfig.setAddress(ConfigKeys.BALANCER_VAULT_ADDRESS, addresses[0]);
        gyroConfig.setAddress(ConfigKeys.FEE_BANK_ADDRESS, addresses[0]);
        gyroConfig.setAddress(ConfigKeys.RESERVE_MANAGER_ADDRESS, address(mockReserveManager));

        reserveSafetyManager = new TestingReserveSafetyManager(
            governorAddress,
            _maxAllowedVaultDeviation,
            _stablecoinMaxDeviation,
            _minTokenPrice
        );
        gyroConfig.setAddress(ConfigKeys.ROOT_SAFETY_CHECK_ADDRESS, address(reserveSafetyManager));
        gyroConfig.setAddress(ConfigKeys.FEE_HANDLER_ADDRESS, address(feeHandler));
        gyroConfig.setAddress(ConfigKeys.PAMM_ADDRESS, address(mockPAMMv1));

        motherboard = new Motherboard(gyroConfig);
    }

    function testDryMint() public {
        DataTypes.ReserveState memory reserveState = mockReserveManager.getReserveState();
        DataTypes.MintAsset[] memory assets = new DataTypes.MintAsset[](1);
        assets[0] = DataTypes.MintAsset(
            reserveState.vaults[0].underlying,
            1e15,
            reserveState.vaults[0].vault
        );
        // assets[1] = DataTypes.MintAsset(addresses[1], 1e18, addresses[1]);
        // assets[2] = DataTypes.MintAsset(addresses[2], 1e18, addresses[2]);
        // assets[3] = DataTypes.MintAsset(addresses[3], 1e18, addresses[3]);
        (uint256 mintedGYDAmount, string memory err) = motherboard.dryMint(assets, 0, userAddress);

        console.log(mintedGYDAmount, err);
    }

    // Create addresses
    function createAddresses(uint256 addressNum) internal pure returns (address[] memory) {
        address[] memory output = new address[](addressNum);

        for (uint256 i = 0; i < addressNum; i++) {
            // This will create a new address using `keccak256(i)` as the private key
            address account = vm.addr(uint256(keccak256(abi.encodePacked(i))));
            output[i] = account;
        }

        return output;
    }
}

// Mock Contract

contract MockReserveManager {
    // Vaults
    MockGyroVault internal vault1 = new MockGyroVault(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619); // WETH Vault

    function getReserveState() public view returns (DataTypes.ReserveState memory) {
        uint256 totalUSDValue = 10432425163587914422052;
        DataTypes.VaultInfo[] memory vaults = new DataTypes.VaultInfo[](4);

        // Persisted Vault Metadata
        DataTypes.PersistedVaultMetadata memory persistedMetadata0 = DataTypes
            .PersistedVaultMetadata(
                1592300000000000000000,
                20000000000000000,
                999941468093248996,
                12000000000000000000
            );

        DataTypes.PersistedVaultMetadata memory persistedMetadata1 = DataTypes
            .PersistedVaultMetadata(
                1765024354913935136283,
                330000000000000000,
                999941468093248996,
                11325052200493400000
            );

        DataTypes.PersistedVaultMetadata memory persistedMetadata2 = DataTypes
            .PersistedVaultMetadata(
                501288984245543,
                320000000000000000,
                999941468093248996,
                39895019889899642339860000
            );

        DataTypes.PersistedVaultMetadata memory persistedMetadata3 = DataTypes
            .PersistedVaultMetadata(
                2496643050889703,
                330000000000000000,
                999941468093248996,
                8008320448663566239740000
            );

        // Priced Tokens
        DataTypes.PricedToken[] memory pricedTokens0 = new DataTypes.PricedToken[](1);

        pricedTokens0[0] = DataTypes.PricedToken(
            0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619,
            false,
            1573380000000000000000
        );

        DataTypes.PricedToken[] memory pricedTokens1 = new DataTypes.PricedToken[](2);

        pricedTokens1[0] = DataTypes.PricedToken(
            0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174,
            true,
            999952440000000000
        );

        pricedTokens1[1] = DataTypes.PricedToken(
            0x2e1AD108fF1D8C782fcBbB89AAd783aC49586756,
            true,
            1000485210000000000
        );

        DataTypes.PricedToken[] memory pricedTokens2 = new DataTypes.PricedToken[](3);

        pricedTokens2[0] = DataTypes.PricedToken(
            0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174,
            true,
            999952440000000000
        );

        pricedTokens2[1] = DataTypes.PricedToken(
            0x9C9e5fD8bbc25984B178FdCE6117Defa39d2db39,
            true,
            1000031900000000000
        );

        pricedTokens2[2] = DataTypes.PricedToken(
            0xc2132D05D31c914a87C6611C10748AEb04B58e8F,
            true,
            1000024100000000000
        );

        DataTypes.PricedToken[] memory pricedTokens3 = new DataTypes.PricedToken[](2);

        pricedTokens3[0] = DataTypes.PricedToken(
            0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174,
            true,
            999952440000000000
        );

        pricedTokens3[1] = DataTypes.PricedToken(
            0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            true,
            999760000000000000
        );

        // VaultInfo
        vaults[0] = DataTypes.VaultInfo(
            address(vault1),
            18,
            0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619,
            1573380000000000000000,
            persistedMetadata0,
            169521365746249958,
            25566589000682946,
            19727762897447015,
            pricedTokens0
        );

        vaults[1] = DataTypes.VaultInfo(
            0x67D204645F4639ABFf0a91F45b3236a3D7541829,
            18,
            0x97469E6236bD467cd147065f77752b00EfadCe8a,
            1767080006682000812070,
            persistedMetadata1,
            1394359404990713968,
            236181385253350134,
            329806009138285346,
            pricedTokens1
        );

        vaults[2] = DataTypes.VaultInfo(
            0x1E6aFF38A1A908b71ad36834895515c9cf3b786b,
            18,
            0x17f1Ef81707811eA15d9eE7c741179bbE2A63887,
            503719659964083,
            persistedMetadata2,
            6655747129713381473542683,
            321366377272253624,
            320988765417604322,
            pricedTokens2
        );

        vaults[3] = DataTypes.VaultInfo(
            0x741B6291b4fA578523b15C006eB37531C18e3C8c,
            18,
            0xdAC42eeb17758Daa38CAF9A3540c808247527aE3,
            2497060783216999,
            persistedMetadata3,
            1741699024191468893811285,
            416885648473713294,
            329477462546663317,
            pricedTokens3
        );

        return DataTypes.ReserveState(totalUSDValue, vaults);
    }
}

contract MockPAMMV1 {
    /// @notice Returns the USD value to mint given an ammount of Gyro dollars
    function computeMintAmount(uint256 usdAmount, uint256) external pure returns (uint256) {
        return usdAmount;
    }
}

contract MockFeeHandler {
    function applyFees(
        DataTypes.Order memory order
    ) external pure returns (DataTypes.Order memory) {
        return order;
    }
}
