// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "../ReserveManager.sol";
import "../PrimaryAMMV1.sol";
import "../../interfaces/IPAMM.sol";
import "../../libraries/DataTypes.sol";

/// @title ReserveSystemRead is a view only contract which allows the UI to retrieve important reserve variables in one RPC call
contract ReserveSystemRead {
    ReserveManager immutable reserveManager;
    PrimaryAMMV1 immutable primaryAMMV1;

    struct ReadValues {
        DataTypes.ReserveState reserveState;
        IPAMM.Params systemParams;
        uint256 redemptionLevel;
        uint256 redemptionPrice;
    }

    struct ReadValuesWithoutReserveState {
        IPAMM.Params systemParams;
        uint256 redemptionLevel;
        uint256 redemptionPrice;
    }

    constructor(ReserveManager _reserveManager, PrimaryAMMV1 _primaryAMMV1) {
        reserveManager = _reserveManager;
        primaryAMMV1 = _primaryAMMV1;
    }

    function read() external view returns (ReadValues memory) {
        DataTypes.ReserveState memory reserveState = reserveManager.getReserveState();

        (uint64 alphaBar, uint64 xuBar, uint64 thetaBar, uint64 outflowMemory) = primaryAMMV1
            .systemParams();

        uint256 redemptionLevel = primaryAMMV1.redemptionLevel();

        IPAMM.Params memory systemParams = IPAMM.Params(alphaBar, xuBar, thetaBar, outflowMemory);

        uint256 redemptionPrice = primaryAMMV1.computeRedeemAmount(
            1e18,
            reserveState.totalUSDValue
        );

        return ReadValues(reserveState, systemParams, redemptionLevel, redemptionPrice);
    }

    function readWithoutReserveState(uint256 totalUSDValue)
        external
        view
        returns (ReadValuesWithoutReserveState memory)
    {
        (uint64 alphaBar, uint64 xuBar, uint64 thetaBar, uint64 outflowMemory) = primaryAMMV1
            .systemParams();

        uint256 redemptionLevel = primaryAMMV1.redemptionLevel();

        IPAMM.Params memory systemParams = IPAMM.Params(alphaBar, xuBar, thetaBar, outflowMemory);

        uint256 redemptionPrice = primaryAMMV1.computeRedeemAmount(1e18, totalUSDValue);

        return ReadValuesWithoutReserveState(systemParams, redemptionLevel, redemptionPrice);
    }
}
