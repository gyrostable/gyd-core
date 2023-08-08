// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {TestingReserveSafetyManager} from "../../contracts/testing/TestingReserveSafetyManager.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";
import "../../libraries/DecimalScale.sol";
import "../../libraries/FixedPoint.sol";

contract ReserveSafetyManagerTest is Test {
    using FixedPoint for uint256;
    using DecimalScale for uint256;

    TestingReserveSafetyManager internal reserveSafetyManager;

    address public constant governorAddress = address(0);
    uint256 internal _maxAllowedVaultDeviation = 3e17;
    uint256 internal _stablecoinMaxDeviation = 5e16;
    uint256 internal _minTokenPrice = 1e14;

    function setUp() public virtual {
        reserveSafetyManager = new TestingReserveSafetyManager(
            governorAddress,
            _maxAllowedVaultDeviation,
            _minTokenPrice
        );
    }

    function testIdealVaultsPass() public view {
        DataTypes.Order memory order = _buildIdealOrder(true);
        reserveSafetyManager.isMintSafe(order);
    }

    function testIsRedeemFeasible(uint8 index, uint256 amount) public {
        vm.assume(index < 4);
        DataTypes.Order memory order = _buildIdealOrder(false);
        DataTypes.VaultWithAmount memory targetVaultWithAmount = order.vaultsWithAmount[index];

        vm.assume(amount > targetVaultWithAmount.vaultInfo.reserveBalance);
        targetVaultWithAmount.amount = amount;

        string memory errString = reserveSafetyManager.isRedeemSafe(order);

        assertEq("56", errString);
    }

    function testIsTokenPricesTooSmall(uint256 price, bool isMint) public {
        DataTypes.Order memory order = _buildIdealOrder(isMint);
        DataTypes.VaultWithAmount memory targetVaultWithAmount = order.vaultsWithAmount[3];

        vm.assume(price < _minTokenPrice);
        targetVaultWithAmount.vaultInfo.pricedTokens[0].price = price;

        string memory errString;

        errString = isMint
            ? reserveSafetyManager.isMintSafe(order)
            : reserveSafetyManager.isRedeemSafe(order);

        assertEq("55", errString);
    }

    function testMintFailsWhenStableCoinOffPegAndVaultWeightRises(uint256 price) public {
        DataTypes.Order memory order = _buildIdealOrder(true);
        DataTypes.PricedToken memory pricedToken = order.vaultsWithAmount[0].vaultInfo.pricedTokens[
            0
        ];
        vm.assume(
            price < pricedToken.price.mulDown(1e18 - _stablecoinMaxDeviation) ||
                price > pricedToken.price.mulDown(1e18 + _stablecoinMaxDeviation)
        );
        pricedToken.price = price;

        // Zero amount for other vaults, ensures vault weight rises for offpeg vault
        order.vaultsWithAmount[1].amount = 0;
        order.vaultsWithAmount[2].amount = 0;
        order.vaultsWithAmount[3].amount = 0;

        string memory errString = reserveSafetyManager.isMintSafe(order);

        assertEq("52", errString);
    }

    /// @dev map x from [0, type max] to [a, b]
    function mapToInterval(
        uint32 x,
        uint256 a,
        uint256 b
    ) public pure returns (uint256) {
        vm.assume(a < b); // retry for fuzz tests, fail for regular tests (not used there)

        // order matters b/c integers!
        return a + ((b - a) * uint256(x)) / type(uint32).max;
    }

    function testMintFailsWhenVaultOutsideEpsilonAndUnsafeToExecute(uint32 amount0) public {
        DataTypes.Order memory order = _buildIdealOrder(true);

        uint256 lowerBound = 515_000e18; // Lower bound such that resulting weight ~41.6% for this vault
        uint256 amount = mapToInterval(amount0, lowerBound, 1e30);

        order.vaultsWithAmount[0].amount = amount;

        // Zero amount for other vaults, ensures vault weight rises for offpeg vault
        order.vaultsWithAmount[1].amount = 0;
        order.vaultsWithAmount[2].amount = 0;
        order.vaultsWithAmount[3].amount = 0;

        string memory errString = reserveSafetyManager.isMintSafe(order);

        assertEq("52", errString);
    }

    function testRedeemFailsWhenOutsideEpsilonAndDivergesFromIdealWeight() public {
        DataTypes.Order memory order = _buildIdealOrder(false);

        uint256 ratio = _maxAllowedVaultDeviation + 0.2e18;

        order.vaultsWithAmount[0].amount = ratio.mulDown(
            order.vaultsWithAmount[0].vaultInfo.reserveBalance
        );

        // Zero amount for other vaults, ensures vault weight falls away from ideal (unsafe to execute outside epsilon)
        order.vaultsWithAmount[1].amount = 0;
        order.vaultsWithAmount[2].amount = 0;
        order.vaultsWithAmount[3].amount = 0;

        string memory errString = reserveSafetyManager.isRedeemSafe(order);
        assertEq("53", errString);
    }

    /////////////////////////////////
    // Helper functions
    /////////////////////////////////

    function _buildIdealOrder(bool isMint) private view returns (DataTypes.Order memory order) {
        DataTypes.VaultWithAmount[] memory vaultsWithAmount = new DataTypes.VaultWithAmount[](4);

        for (uint256 i = 0; i < 4; i++) {
            DataTypes.VaultInfo memory vaultInfo = _buildIdealVaultInfo(i, i == 3);
            uint256 amount = 10e18;
            DataTypes.VaultWithAmount memory newVaultWithAmount = DataTypes.VaultWithAmount(
                vaultInfo,
                amount
            );
            vaultsWithAmount[i] = newVaultWithAmount;
        }

        order.vaultsWithAmount = vaultsWithAmount;
        order.mint = isMint;
    }

    function _buildIdealVaultInfo(uint256 vaultIndex, bool isWETH)
        internal
        view
        returns (DataTypes.VaultInfo memory vaultInfo)
    {
        address vault = address(uint160(vaultIndex));
        uint8 decimals = 18;
        // Random address
        address underlying = address(
            uint160(uint256(keccak256(abi.encodePacked(vaultIndex, blockhash(block.number)))))
        );
        uint256 price = isWETH ? 0.125e18 : 1e18;
        DataTypes.PersistedVaultMetadata memory persistedMetadata = DataTypes
            .PersistedVaultMetadata(1e18, isWETH ? 0.04e18 : 0.32e18, 0, 0, 0, 0, 0);
        uint256 reserveBalance = 1_000_000e18;
        uint256 currentWeight = isWETH ? 0.04e18 : 0.32e18;
        uint256 idealWeight = isWETH ? 0.04e18 : 0.32e18;
        DataTypes.PricedToken[] memory pricedTokens = _buildIdealPricedTokens(!isWETH);

        vaultInfo = DataTypes.VaultInfo(
            vault,
            decimals,
            underlying,
            price,
            persistedMetadata,
            reserveBalance,
            currentWeight,
            idealWeight,
            pricedTokens
        );
    }

    function _buildIdealPricedTokens(bool isStablecoinPair)
        internal
        pure
        returns (DataTypes.PricedToken[] memory)
    {
        DataTypes.PricedToken[] memory pricedTokens = new DataTypes.PricedToken[](
            isStablecoinPair ? 2 : 1
        );
        if (isStablecoinPair) {
            DataTypes.PricedToken memory pricedToken0 = DataTypes.PricedToken(
                address(uint160(1)),
                true,
                1e18,
                DataTypes.Range(0, UINT256_MAX)
            );
            DataTypes.PricedToken memory pricedToken1 = DataTypes.PricedToken(
                address(uint160(2)),
                true,
                1e18,
                DataTypes.Range(0, UINT256_MAX)
            );
            pricedTokens[0] = pricedToken0;
            pricedTokens[1] = pricedToken1;
        } else {
            DataTypes.PricedToken memory pricedToken = DataTypes.PricedToken(
                address(uint160(3)),
                false,
                1000e18,
                DataTypes.Range(0, UINT256_MAX)
            );
            pricedTokens[0] = pricedToken;
        }

        return pricedTokens;
    }
}
