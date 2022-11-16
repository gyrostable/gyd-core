// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "../../libraries/Errors.sol";
import "../../interfaces/IAssetRegistry.sol";
import "../../interfaces/oracles/IUSDPriceOracle.sol";

contract TrustedSignerPriceOracle is IUSDPriceOracle {
    /// @notice prices posted should be scaled using `PRICE_DECIMALS` decimals
    uint8 public constant PRICE_DECIMALS = 6;

    /// @notice we throw an error if the price is older than `MAX_LAG` seconds
    uint256 public constant MAX_LAG = 3600;

    /// @notice this event is emitted when the price of `asset` is updated
    event PriceUpdated(address indexed asset, uint256 price, uint256 timestamp);

    struct SignedPrice {
        bytes message;
        bytes signature;
    }

    struct PriceData {
        uint64 timestamp;
        uint128 price;
    }

    /// @notice address of the trusted price signer
    /// This should be the Coinbase signing address in production deployments
    /// i.e. 0xfCEAdAFab14d46e20144F48824d0C09B1a03F2BC
    address public immutable trustedPriceSigner;

    /// @notice the asset registry used to find the mapping between
    /// a token address and its address
    IAssetRegistry public immutable assetRegistry;

    /// @dev asset to prices storage
    mapping(address => PriceData) internal prices;

    constructor(address _assetRegistry, address _priceSigner) {
        assetRegistry = IAssetRegistry(_assetRegistry);
        trustedPriceSigner = _priceSigner;
    }

    /// @inheritdoc IUSDPriceOracle
    function getPriceUSD(address baseAsset) external view returns (uint256) {
        PriceData memory signedPrice = prices[baseAsset];
        require(signedPrice.timestamp > 0, Errors.ASSET_NOT_SUPPORTED);
        require(signedPrice.timestamp + MAX_LAG >= block.timestamp, Errors.STALE_PRICE);
        return signedPrice.price;
    }

    /// @notice returns the last update of `asset` or 0 if `asset` has never been updated
    function getLastUpdate(address asset) external view returns (uint256) {
        return prices[asset].timestamp;
    }

    /// @notice Updates prices using a list of signed prices received from a trusted signer (e.g. Coinbase)
    function postPrices(SignedPrice[] calldata signedPrices) external {
        for (uint256 i = 0; i < signedPrices.length; i++) {
            SignedPrice calldata signedPrice = signedPrices[i];
            _postPrice(signedPrice.message, signedPrice.signature);
        }
    }

    /// @notice Upates the price with a message containing the price information and its signature
    /// The message should have the following ABI-encoded format: (string kind, uint256 timestamp, string key, uint256 price)
    function postPrice(bytes memory message, bytes memory signature) external {
        _postPrice(message, signature);
    }

    function _postPrice(bytes memory message, bytes memory signature) internal {
        address signingAddress = verifyMessage(message, signature);
        require(signingAddress == trustedPriceSigner, Errors.INVALID_MESSAGE);

        (uint256 timestamp, string memory assetName, uint256 price) = decodeMessage(message);
        address assetAddress = assetRegistry.getAssetAddress(assetName);
        PriceData storage priceData = prices[assetAddress];
        require(
            timestamp > priceData.timestamp && timestamp + MAX_LAG >= block.timestamp,
            Errors.STALE_PRICE
        );

        uint256 scaledPrice = price * 10**(18 - PRICE_DECIMALS);

        priceData.timestamp = uint64(timestamp);
        priceData.price = uint128(scaledPrice);

        emit PriceUpdated(assetAddress, scaledPrice, timestamp);
    }

    function decodeMessage(bytes memory message)
        internal
        pure
        returns (
            uint256,
            string memory,
            uint256
        )
    {
        (string memory kind, uint256 timestamp, string memory key, uint256 value) = abi.decode(
            message,
            (string, uint256, string, uint256)
        );
        require(
            keccak256(abi.encodePacked(kind)) == keccak256(abi.encodePacked("prices")),
            Errors.INVALID_MESSAGE
        );
        return (timestamp, key, value);
    }

    function verifyMessage(bytes memory message, bytes memory signature)
        internal
        pure
        returns (address)
    {
        (bytes32 r, bytes32 s, uint8 v) = abi.decode(signature, (bytes32, bytes32, uint8));
        bytes32 signedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(message))
        );
        return ecrecover(signedHash, v, r, s);
    }
}
