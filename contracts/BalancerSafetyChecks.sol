// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../interfaces/balancer/IVault.sol";
import "../interfaces/IBalancerPool.sol";
import "../interfaces/IAssetRegistry.sol";
import "../libraries/DataTypes.sol";
import "../libraries/FixedPoint.sol";
import "../interfaces/IAssetPricer.sol";
import "../interfaces/oracles/IUSDPriceOracle.sol";
import "../interfaces/IBalancerSafetyChecks.sol";
import "./auth/Governable.sol";

/**
    @title Contract containing the safety checks performed on Balancer pools
//  */
contract BalancerSafetyChecks is Ownable, Governable {
    using SafeERC20 for ERC20;
    using FixedPoint for uint256;

    /// @notice a stablecoin should be equal 1 USD
    uint256 public constant STABLECOIN_IDEAL_PRICE = 1e18;

    address private balancerVaultAddress;
    address private assetRegistryAddress;
    address private assetPricerAddress;
    address private priceOracleAddress;
    uint256 private maxActivityLag;
    uint256 private stablecoinMaxDeviation;
    uint256 private poolWeightMaxDeviation;

    constructor(
        address _balancerVaultAddress,
        address _assetRegistryAddress,
        address _priceOracleAddress,
        address _assetPricerAddress,
        uint256 _maxActivityLag,
        uint256 _stablecoinMaxDeviation,
        uint256 _poolWeightMaxDeviation
    ) {
        balancerVaultAddress = _balancerVaultAddress;
        assetRegistryAddress = _assetRegistryAddress;
        assetPricerAddress = _assetPricerAddress;
        priceOracleAddress = _priceOracleAddress;
        maxActivityLag = _maxActivityLag;
        stablecoinMaxDeviation = _stablecoinMaxDeviation; /// @dev this should be scaled by 10^18, i.e. 1e16 == 1%
        poolWeightMaxDeviation = _poolWeightMaxDeviation; /// @dev this should be scaled by 10^18, i.e. 1e16 == 1%
    }

    function getBalancerVaultAddress() external view returns (address) {
        return balancerVaultAddress;
    }

    function setBalancerVaultAddress(address _balancerVaultAddress) external governanceOnly {
        balancerVaultAddress = _balancerVaultAddress;
    }

    function getAssetRegistryAddress() external view returns (address) {
        return assetRegistryAddress;
    }

    function setAssetRegistryAddress(address _assetRegistryAddress) external governanceOnly {
        assetRegistryAddress = _assetRegistryAddress;
    }

    function getPriceOracleAddress() external view returns (address) {
        return priceOracleAddress;
    }

    function setPriceOracleAddress(address _priceOracleAddress) external governanceOnly {
        priceOracleAddress = _priceOracleAddress;
    }

    function getAssetPricerAddress() external view returns (address) {
        return assetPricerAddress;
    }

    function setAssetPricerAddress(address _assetPricerAddress) external governanceOnly {
        assetPricerAddress = _assetPricerAddress;
    }

    function getMaxActivityLag() external view returns (uint256) {
        return maxActivityLag;
    }

    function setMaxActivityLag(uint256 _maxActivityLag) external governanceOnly {
        maxActivityLag = _maxActivityLag;
    }

    function getStablecoinMaxDeviation() external view returns (uint256) {
        return stablecoinMaxDeviation;
    }

    function setStablecoinMaxDeviation(uint256 _stablecoinMaxDeviation) external governanceOnly {
        stablecoinMaxDeviation = _stablecoinMaxDeviation;
    }

    function getPoolWeightMaxDeviation() external view returns (uint256) {
        return poolWeightMaxDeviation;
    }

    function setPoolWeightMaxDeviation(uint256 _poolWeightMaxDeviation) external governanceOnly {
        poolWeightMaxDeviation = _poolWeightMaxDeviation;
    }

    // / @inheritdoc IBalancerSafetyChecks
    function isPoolPaused(bytes32 poolId) public view returns (bool) {
        IVault balVault = IVault(balancerVaultAddress);
        (address poolAddress, ) = balVault.getPool(poolId);
        require(poolAddress != address(0), Errors.NO_POOL_ID_REGISTERED);
        IBalancerPool balancerPool = IBalancerPool(poolAddress);
        (bool paused, , ) = balancerPool.getPausedState();
        return paused;
    }

    function _makeMonetaryAmounts(IERC20[] memory _tokens, uint256[] memory _balances)
        internal
        pure
        returns (DataTypes.MonetaryAmount[] memory)
    {
        require(_tokens.length == _balances.length, Errors.TOKEN_AND_AMOUNTS_LENGTH_DIFFER);
        DataTypes.MonetaryAmount[] memory monetaryAmounts = new DataTypes.MonetaryAmount[](
            _tokens.length
        );
        for (uint256 i = 0; i < _tokens.length; i++) {
            monetaryAmounts[i] = DataTypes.MonetaryAmount({
                tokenAddress: address(_tokens[i]),
                amount: _balances[i]
            });
        }
        return monetaryAmounts;
    }

    function _computeActualWeights(DataTypes.MonetaryAmount[] memory monetaryAmounts)
        internal
        view
        returns (uint256[] memory)
    {
        uint256 totalPoolUSDValue = 0;
        uint256[] memory usdValues = new uint256[](monetaryAmounts.length);

        IAssetPricer assetPricer = IAssetPricer(assetPricerAddress);

        for (uint256 i = 0; i < monetaryAmounts.length; i++) {
            uint256 usdValue = assetPricer.getUSDValue(monetaryAmounts[i]);
            usdValues[i] = usdValue;
            totalPoolUSDValue = totalPoolUSDValue + usdValue;
        }

        if (totalPoolUSDValue == 0) {
            uint256[] memory nilWeights = new uint256[](monetaryAmounts.length);
            return nilWeights;
        }

        uint256[] memory weights = new uint256[](monetaryAmounts.length);

        for (uint256 i = 0; i < monetaryAmounts.length; i++) {
            weights[i] = usdValues[i].divDown(totalPoolUSDValue);
        }

        return weights;
    }

    // / @inheritdoc IBalancerSafetyChecks
    function arePoolAssetWeightsCloseToExpected(bytes32 poolId) public view returns (bool) {
        IVault balVault = IVault(balancerVaultAddress);
        (address poolAddress, ) = balVault.getPool(poolId);
        IBalancerPool balancerPool = IBalancerPool(poolAddress);

        (IERC20[] memory tokens, uint256[] memory balances, ) = balVault.getPoolTokens(poolId);
        require(tokens.length == balances.length, Errors.DIFFERENT_NUMBER_OF_TOKENS_TO_BALANCES);

        DataTypes.MonetaryAmount[] memory monetaryAmounts = _makeMonetaryAmounts(tokens, balances);

        uint256[] memory weights = _computeActualWeights(monetaryAmounts);

        uint256[] memory expectedWeights = balancerPool.getNormalizedWeights();

        require(
            expectedWeights.length == tokens.length,
            Errors.POOL_DOES_NOT_HAVE_NORMALIZED_WEIGHTS_SET
        );

        for (uint256 i = 0; i < weights.length; i++) {
            if (weights[i].absSub(expectedWeights[i]) >= poolWeightMaxDeviation) {
                return false;
            }
        }

        return true;
    }

    // / @inheritdoc IBalancerSafetyChecks
    function doesPoolHaveLiveness(bytes32 poolId) public view returns (bool) {
        IVault balVault = IVault(balancerVaultAddress);
        (, , uint256 lastChangeBlock) = balVault.getPoolTokens(poolId);
        bool lastChangeRecent = block.number - lastChangeBlock <= maxActivityLag;
        return lastChangeRecent;
    }

    /// @dev stablecoinPrice must be scaled to 10^18
    function isStablecoinCloseToPeg(uint256 stablecoinPrice) internal view returns (bool) {
        return stablecoinPrice.absSub(STABLECOIN_IDEAL_PRICE) <= stablecoinMaxDeviation;
    }

    // / @inheritdoc IBalancerSafetyChecks
    function areAllPoolStablecoinsCloseToPeg(bytes32 poolId) public view returns (bool) {
        IVault balVault = IVault(balancerVaultAddress);
        IUSDPriceOracle priceOracle = IUSDPriceOracle(priceOracleAddress);
        IAssetRegistry assetRegistry = IAssetRegistry(assetRegistryAddress);

        (IERC20[] memory tokens, , ) = balVault.getPoolTokens(poolId);

        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenAddress = address(tokens[i]);

            if (!assetRegistry.isAssetStable(tokenAddress)) {
                continue;
            }

            uint256 stablecoinPrice = priceOracle.getPriceUSD(tokenAddress);
            bool isCloseToPeg = isStablecoinCloseToPeg(stablecoinPrice);

            if (!isCloseToPeg) {
                return false;
            }
        }

        return true;
    }

    // / @inheritdoc IBalancerSafetyChecks
    function ensurePoolsSafe(bytes32[] memory poolIds) public {
        for (uint256 i = 0; i < poolIds.length; i++) {
            bool poolLiveness = doesPoolHaveLiveness(poolIds[i]);
            require(poolLiveness, Errors.POOL_DOES_NOT_HAVE_LIVENESS);

            bool poolPaused = isPoolPaused(poolIds[i]);
            require(!poolPaused, Errors.POOL_IS_PAUSED);

            bool assetsNearWeights = arePoolAssetWeightsCloseToExpected(poolIds[i]);
            require(assetsNearWeights, Errors.ASSETS_NOT_CLOSE_TO_POOL_WEIGHTS);

            bool stablecoinsInPoolCloseToPeg = areAllPoolStablecoinsCloseToPeg(poolIds[i]);
            require(stablecoinsInPoolCloseToPeg, Errors.STABLECOIN_IN_POOL_NOT_CLOSE_TO_PEG);
        }
    }
}
