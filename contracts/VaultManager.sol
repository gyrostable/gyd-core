// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../libraries/FixedPoint.sol";
import "../interfaces/IVaultManager.sol";
import "../interfaces/IVaultRegistry.sol";
import "./auth/Governable.sol";

contract VaultManager is IVaultManager, Governable {
    using FixedPoint for uint256;

    IVaultRegistry public immutable vaultRegistry;
    address public reserveAddress;

    IVaultWeightManager vaultWeightManager;
    IVaultPriceOracle vaultPriceOracle;

    constructor(address _vaultRegistry, address _reserve) {
        vaultRegistry = IVaultRegistry(_vaultRegistry);
        reserveAddress = _reserve;
    }

    /// @inheritdoc IVaultManager
    function listVaults() external view returns (DataTypes.VaultInfo[] memory) {
        return listVaults(false, false, false);
    }

    /// @inheritdoc IVaultManager
    function listVaults(
        bool includeIdealWeight,
        bool includePrice,
        bool includeCurrentWeight
    ) public view returns (DataTypes.VaultInfo[] memory) {
        require(!includeCurrentWeight || includePrice, Errors.INVALID_ARGUMENT);

        address[] memory vaultAddresses = vaultRegistry.listVaults();

        uint256[] memory weights;
        if (includeIdealWeight) {
            weights = vaultWeightManager.getVaultWeights(vaultAddresses);
        }

        uint256[] memory prices;
        if (includePrice) {
            prices = vaultPriceOracle.getVaultTokenPrices(vaultAddresses);
        }

        uint256 length = vaultAddresses.length;
        DataTypes.VaultInfo[] memory result = new DataTypes.VaultInfo[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 idealWeight = includeIdealWeight ? weights[i] : 0;
            uint256 price = includePrice ? prices[i] : 0;

            uint256 reserveBalance = includeCurrentWeight
                ? IERC20(vaultAddresses[i]).balanceOf(reserveAddress)
                : 0;

            result[i] = DataTypes.VaultInfo({
                vault: vaultAddresses[i],
                idealWeight: idealWeight,
                reserveBalance: reserveBalance,
                price: price,
                currentWeight: 0
            });
        }

        if (includeCurrentWeight) {
            uint256 reserveUSDValue = 0;
            uint256[] memory usdValues = new uint256[](length);
            for (uint256 i = 0; i < length; i++) {
                uint256 usdValue = result[i].price.mulDown(result[i].reserveBalance);
                usdValues[i] = usdValue;
                reserveUSDValue += usdValue;
            }
            for (uint256 i = 0; i < length; i++) {
                result[i].currentWeight = usdValues[i].divDown(reserveUSDValue);
            }
        }

        return result;
    }

    /// @inheritdoc IVaultManager
    function getVaultPriceOracle() external view override returns (IVaultPriceOracle) {
        return vaultPriceOracle;
    }

    /// @inheritdoc IVaultManager
    function setVaultPriceOracle(address priceOracle) external override governanceOnly {
        address currentOracle = address(vaultPriceOracle);
        vaultPriceOracle = IVaultPriceOracle(priceOracle);
        emit NewVaultPriceOracle(currentOracle, priceOracle);
    }

    /// @inheritdoc IVaultManager
    function getVaultWeightManager() external view override returns (IVaultWeightManager) {
        return vaultWeightManager;
    }

    /// @inheritdoc IVaultManager
    function setVaultWeightManager(address vaultManager) external override governanceOnly {
        address currentManager = address(vaultWeightManager);
        vaultWeightManager = IVaultWeightManager(vaultManager);
        emit NewVaultWeightManager(currentManager, vaultManager);
    }
}
