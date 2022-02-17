// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../libraries/FixedPoint.sol";
import "../libraries/ConfigHelpers.sol";
import "../libraries/ConfigKeys.sol";
import "../interfaces/IVaultManager.sol";
import "../interfaces/oracles/IUSDPriceOracle.sol";
import "../interfaces/IVaultRegistry.sol";
import "../interfaces/IGyroConfig.sol";
import "./auth/Governable.sol";

contract VaultManager is IVaultManager, Governable {
    using FixedPoint for uint256;
    using ConfigHelpers for IGyroConfig;

    IVaultRegistry public immutable vaultRegistry;
    address public immutable reserveAddress;

    IUSDPriceOracle internal priceOracle;

    constructor(IGyroConfig _gyroConfig) {
        vaultRegistry = _gyroConfig.getVaultRegistry();
        reserveAddress = _gyroConfig.getAddress(ConfigKeys.RESERVE_ADDRESS);
        priceOracle = _gyroConfig.getRootPriceOracle();
    }

    /// @inheritdoc IVaultManager
    function listVaults()
        external
        view
        returns (DataTypes.VaultInfo[] memory, uint256 reserveUSDValue)
    {
        return listVaults(true, true, true, true);
    }

    function listVaults(
        bool includeMetadata,
        bool includePrice,
        bool includeCurrentWeight,
        bool includeIdealWeight
    ) public view returns (DataTypes.VaultInfo[] memory, uint256 reserveUSDValue) {
        require(!includeCurrentWeight || includePrice, Errors.INVALID_ARGUMENT);

        address[] memory vaultAddresses = vaultRegistry.listVaults();

        uint256[] memory prices = new uint256[](vaultAddresses.length);
        if (includePrice) {
            for (uint256 i = 0; i < vaultAddresses.length; i++) {
                prices[i] = priceOracle.getPriceUSD(vaultAddresses[i]);
            }
        }

        uint256 length = vaultAddresses.length;
        DataTypes.VaultInfo[] memory vaultsInfo = new DataTypes.VaultInfo[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 price = includePrice ? prices[i] : 0;

            DataTypes.PersistedVaultMetadata memory persistedMetadata;
            if (includeMetadata) {
                persistedMetadata = vaultRegistry.getVaultMetadata(vaultAddresses[i]);
            }

            uint256 reserveBalance = includeCurrentWeight
                ? IERC20(vaultAddresses[i]).balanceOf(reserveAddress)
                : 0;

            vaultsInfo[i] = DataTypes.VaultInfo({
                vault: vaultAddresses[i],
                persistedMetadata: persistedMetadata,
                reserveBalance: reserveBalance,
                price: price,
                currentWeight: 0,
                idealWeight: 0
            });
        }

        if (includeCurrentWeight) {
            uint256[] memory usdValues = new uint256[](length);
            for (uint256 i = 0; i < length; i++) {
                uint256 usdValue = vaultsInfo[i].price.mulDown(vaultsInfo[i].reserveBalance);
                usdValues[i] = usdValue;
                reserveUSDValue += usdValue;
            }
            for (uint256 i = 0; i < length; i++) {
                vaultsInfo[i].currentWeight = reserveUSDValue == 0
                    ? vaultsInfo[i].persistedMetadata.initialWeight
                    : usdValues[i].divDown(reserveUSDValue);
            }
        }

        if (includeIdealWeight) {
            uint256 returnsSum = 0;
            uint256[] memory weightedReturns = new uint256[](length);
            for (uint256 i = 0; i < length; i++) {
                weightedReturns[i] = (vaultsInfo[i].price)
                    .divDown(vaultsInfo[i].persistedMetadata.initialPrice)
                    .mulDown(vaultsInfo[i].persistedMetadata.initialWeight);
                returnsSum += weightedReturns[i];
            }
            for (uint256 i = 0; i < length; i++) {
                vaultsInfo[i].idealWeight = weightedReturns[i].divDown(returnsSum);
            }
        }

        return (vaultsInfo, reserveUSDValue);
    }

    /// @inheritdoc IVaultManager
    function getPriceOracle() external view override returns (IUSDPriceOracle) {
        return priceOracle;
    }

    /// @inheritdoc IVaultManager
    function setPriceOracle(address _priceOracle) external override governanceOnly {
        address currentOracle = address(priceOracle);
        priceOracle = IUSDPriceOracle(_priceOracle);
        emit NewPriceOracle(currentOracle, _priceOracle);
    }
}
