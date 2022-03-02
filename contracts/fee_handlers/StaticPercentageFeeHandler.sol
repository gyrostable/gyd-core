// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../../interfaces/IFeeHandler.sol";

import "../../libraries/Errors.sol";
import "../../libraries/FixedPoint.sol";

import "../auth/Governable.sol";

contract StaticPercentageFeeHandler is IFeeHandler, Governable {
    using FixedPoint for uint256;

    /// @notice Mint and redeem fees cannot be above 20%
    uint64 public constant MAX_FEE = 0.2e18;

    /// @notice holds the mint and redeem fees for a single vault
    struct Fees {
        bool exists;
        uint64 mint;
        uint64 redeem;
    }

    /// @notice mapping from vault to fees
    mapping(address => Fees) public vaultFees;

    /// @notice set the fees for a vault
    function setVaultFees(
        address vault,
        uint64 mintFee,
        uint64 redeemFee
    ) external governanceOnly {
        require(vault != address(0), Errors.INVALID_ARGUMENT);
        require(mintFee <= MAX_FEE && redeemFee <= MAX_FEE, Errors.INVALID_ARGUMENT);
        vaultFees[vault] = Fees({exists: true, mint: mintFee, redeem: redeemFee});
    }

    /// @inheritdoc IFeeHandler
    function applyFees(DataTypes.Order memory order)
        external
        view
        returns (DataTypes.Order memory)
    {
        DataTypes.VaultWithAmount[] memory vaultsWithAmount = new DataTypes.VaultWithAmount[](
            order.vaultsWithAmount.length
        );
        for (uint256 i = 0; i < order.vaultsWithAmount.length; i++) {
            address vaultAddress = order.vaultsWithAmount[i].vaultInfo.vault;
            Fees memory fees = vaultFees[vaultAddress];
            require(fees.exists, Errors.INVALID_ARGUMENT);
            uint256 feeMultiplier = FixedPoint.ONE - (order.mint ? fees.mint : fees.redeem);
            uint256 amountAfterFees = order.vaultsWithAmount[i].amount.mulDown(feeMultiplier);
            vaultsWithAmount[i] = DataTypes.VaultWithAmount({
                vaultInfo: order.vaultsWithAmount[i].vaultInfo,
                amount: amountAfterFees
            });
        }

        return DataTypes.Order(vaultsWithAmount, order.mint);
    }
}
