// SPDX-License-Identifier: Unlicense

// Test script
// forge test --fork-url https://polygon-rpc.com --fork-block-number 40220000 -vv -m testFork
// Note UDSC at 0.91035539 at this point

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./PolygonAddresses.sol";
import "../../../contracts/ReserveManager.sol";
import "../../../contracts/Motherboard.sol";
import "../../../contracts/PrimaryAMMV1.sol";
import "../../../libraries/DataTypes.sol";

contract MintRedeemTest is PolygonAddresses, Test {
    using Address for address;
    using FixedPoint for uint256;
    using DecimalScale for uint256;

    address constant usdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address constant tester = 0x4f62aC9936D383289C13524157d95f3aB3EeF629;
    address constant pGYDHolder = 0xC5250939aB0E1aAF6680D54A2b2154e59a43871e;
    Motherboard constant motherboard = Motherboard(motherboardAddress);

    uint256 usdcDepegBlock = 40220000;

    function testForkLogReserveState() public view {
        console.log(block.number);
        console.log("My balance", address(tester).balance / 1e18);

        (, bytes memory data) = reserveManagerAddress.staticcall(
            abi.encodeWithSignature("getReserveState()")
        );

        DataTypes.ReserveState memory reserveState = abi.decode(data, (DataTypes.ReserveState));

        for (uint i; i < reserveState.vaults.length; i++) {
            DataTypes.VaultInfo memory vault = reserveState.vaults[i];

            console.log("NEW VAULT");
            console.log("Vault address: ", vault.vault);
            console.log("Decimals: ", vault.decimals);
            console.log("Underlying: ", vault.underlying);
            console.log("Price: ", vault.price);
            console.log("Reserve balance: ", vault.reserveBalance);
            console.log("Current weight: ", vault.currentWeight);
            console.log("Ideal weight: ", vault.idealWeight);

            console.log("My balance of underlying: ", ERC20(vault.underlying).balanceOf(tester));

            for (uint j; j < vault.pricedTokens.length; j++) {
                DataTypes.PricedToken memory pricedToken = vault.pricedTokens[j];
                console.log("------------");
                console.log("Priced token", (j + 1));
                console.log("Token address:", pricedToken.tokenAddress);
                console.log("is Stable:", pricedToken.isStable);
                console.log("Price:", pricedToken.price);
            }
            console.log("------------");
            console.log("------------");
        }

        PrimaryAMMV1 primaryAMMV1 = PrimaryAMMV1(primaryAMMV1Address);

        uint256 redemptionPrice = primaryAMMV1.computeRedeemAmount(
            1e18,
            reserveState.totalUSDValue
        );

        uint256 totalSupply = ERC20(gydTokenAddress).totalSupply();

        console.log("\n");
        console.log("Collateralization ratio: ", reserveState.totalUSDValue.divDown(totalSupply));
        console.log("Redemption Price: ", redemptionPrice);
    }

    // Attempt to mint GYD with WETH only or with a vault token which contains depegged USDC, but which reduces the weight of that vault
    function testForkMintSafe() public {
        DataTypes.MintAsset memory mintAssetWETH = DataTypes.MintAsset(
            0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619,
            20000000000000,
            0x65A978eC2f27bED3C9f0b5C3a59B473ef4FfE3d0
        );

        DataTypes.MintAsset memory mintAsset0 = DataTypes.MintAsset(
            0x97469E6236bD467cd147065f77752b00EfadCe8a,
            10000, // Small amount
            0x67D204645F4639ABFf0a91F45b3236a3D7541829
        );

        DataTypes.MintAsset memory mintAsset1 = DataTypes.MintAsset(
            0x17f1Ef81707811eA15d9eE7c741179bbE2A63887,
            10000, // Small amount
            0x1E6aFF38A1A908b71ad36834895515c9cf3b786b
        );

        DataTypes.MintAsset memory mintAsset2 = DataTypes.MintAsset(
            0xdAC42eeb17758Daa38CAF9A3540c808247527aE3,
            10000, // Small amount
            0x741B6291b4fA578523b15C006eB37531C18e3C8c
        );

        // Approve tokens
        vm.startPrank(tester);
        ERC20(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619).approve(
            balancerVaultAddress,
            UINT256_MAX
        );
        ERC20(0x97469E6236bD467cd147065f77752b00EfadCe8a).approve(
            balancerVaultAddress,
            UINT256_MAX
        );
        ERC20(0x1E6aFF38A1A908b71ad36834895515c9cf3b786b).approve(
            balancerVaultAddress,
            UINT256_MAX
        );
        ERC20(0xdAC42eeb17758Daa38CAF9A3540c808247527aE3).approve(
            balancerVaultAddress,
            UINT256_MAX
        );

        DataTypes.MintAsset[] memory mintAssets = new DataTypes.MintAsset[](1);
        mintAssets[0] = mintAssetWETH;
        motherboard.mint(mintAssets, 0);

        mintAssets = new DataTypes.MintAsset[](2);
        mintAssets[0] = mintAssetWETH;
        mintAssets[1] = mintAsset0;
        motherboard.mint(mintAssets, 0);

        mintAssets = new DataTypes.MintAsset[](2);
        mintAssets[0] = mintAssetWETH;
        mintAssets[1] = mintAsset1;
        motherboard.mint(mintAssets, 0);

        mintAssets = new DataTypes.MintAsset[](2);
        mintAssets[0] = mintAssetWETH;
        mintAssets[1] = mintAsset2;
        motherboard.mint(mintAssets, 0);

        // Combination mint
        mintAssets = new DataTypes.MintAsset[](4);
        mintAssets[0] = mintAssetWETH;
        mintAssets[1] = mintAsset0;
        mintAssets[2] = mintAsset1;
        mintAssets[3] = mintAsset2;

        motherboard.mint(mintAssets, 0);

        vm.stopPrank();
    }

    // Attempt to mint GYD with each of the three vault tokens which contain depegged USDC
    function testForkMintNotSafe() public {
        DataTypes.MintAsset memory mintAsset0 = DataTypes.MintAsset(
            0x97469E6236bD467cd147065f77752b00EfadCe8a,
            10000000000000000,
            0x67D204645F4639ABFf0a91F45b3236a3D7541829
        );

        DataTypes.MintAsset memory mintAsset1 = DataTypes.MintAsset(
            0x17f1Ef81707811eA15d9eE7c741179bbE2A63887,
            16918000000000000000000,
            0x1E6aFF38A1A908b71ad36834895515c9cf3b786b
        );

        DataTypes.MintAsset memory mintAsset2 = DataTypes.MintAsset(
            0xdAC42eeb17758Daa38CAF9A3540c808247527aE3,
            2922000000000000000000,
            0x741B6291b4fA578523b15C006eB37531C18e3C8c
        );

        DataTypes.MintAsset[] memory mintAssets = new DataTypes.MintAsset[](1);
        mintAssets[0] = mintAsset0;

        vm.startPrank(tester);
        // Approve tokens
        ERC20(0x97469E6236bD467cd147065f77752b00EfadCe8a).approve(
            balancerVaultAddress,
            UINT256_MAX
        );
        ERC20(0x1E6aFF38A1A908b71ad36834895515c9cf3b786b).approve(
            balancerVaultAddress,
            UINT256_MAX
        );
        ERC20(0xdAC42eeb17758Daa38CAF9A3540c808247527aE3).approve(
            balancerVaultAddress,
            UINT256_MAX
        );

        vm.expectRevert(bytes("52"));
        motherboard.mint(mintAssets, 0);

        mintAssets[0] = mintAsset1;
        vm.expectRevert(bytes("52"));
        motherboard.mint(mintAssets, 0);

        mintAssets[0] = mintAsset2;
        vm.expectRevert(bytes("52"));
        motherboard.mint(mintAssets, 0);

        vm.stopPrank();
    }

    // Attempt to redeem small amount of p-GYD for any combination of vault tokens
    function testForkRedeemSafe() public {
        DataTypes.RedeemAsset memory redeemAsset0 = DataTypes.RedeemAsset(
            0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619,
            0,
            250000000000000000,
            0x65A978eC2f27bED3C9f0b5C3a59B473ef4FfE3d0
        );

        DataTypes.RedeemAsset memory redeemAsset1 = DataTypes.RedeemAsset(
            0x97469E6236bD467cd147065f77752b00EfadCe8a,
            0,
            250000000000000000,
            0x67D204645F4639ABFf0a91F45b3236a3D7541829
        );

        DataTypes.RedeemAsset memory redeemAsset2 = DataTypes.RedeemAsset(
            0x17f1Ef81707811eA15d9eE7c741179bbE2A63887,
            0,
            250000000000000000,
            0x1E6aFF38A1A908b71ad36834895515c9cf3b786b
        );

        DataTypes.RedeemAsset memory redeemAsset3 = DataTypes.RedeemAsset(
            0xdAC42eeb17758Daa38CAF9A3540c808247527aE3,
            0,
            250000000000000000,
            0x741B6291b4fA578523b15C006eB37531C18e3C8c
        );

        DataTypes.RedeemAsset[] memory redeemAssets = new DataTypes.RedeemAsset[](4);
        redeemAssets[0] = redeemAsset0;
        redeemAssets[1] = redeemAsset1;
        redeemAssets[2] = redeemAsset2;
        redeemAssets[3] = redeemAsset3;

        vm.prank(pGYDHolder);
        motherboard.redeem(100000000000000000, redeemAssets); // Redeem 0.1 GYD
    }
}
