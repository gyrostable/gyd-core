// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.10;

// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// import "../interfaces/balancer/IVault.sol";

// contract PAMMSafetyChecks is Ownable {
//     function mintChecksPass(
//         address[] memory _BPTokensIn,
//         uint256[] memory _amountsIn,
//         uint256 _minGyroMinted
//     ) public view override returns (uint256 errorCode, uint256 estimatedMint) {
//         (uint256 _errorCode, Weights memory weights, ) = mintChecksPassInternal(
//             _BPTokensIn,
//             _amountsIn,
//             _minGyroMinted
//         );

//         return (_errorCode, weights.gyroAmount);
//     }

//     function mintChecksPassInternal(
//         address[] memory _BPTokensIn,
//         uint256[] memory _amountsIn,
//         uint256 _minGyroMinted
//     )
//         internal
//         view
//         returns (
//             uint256 errorCode,
//             Weights memory weights,
//             FlowLogger memory flowLogger
//         )
//     {
//         require(
//             _BPTokensIn.length == _amountsIn.length,
//             "tokensIn and valuesIn should have the same number of elements"
//         );

//         //Filter 1: Require that the tokens are supported and in correct order
//         bool _orderCorrect = checkBPTokenOrder(_BPTokensIn);
//         require(
//             _orderCorrect,
//             "Input tokens in wrong order or contains invalid tokens"
//         );

//         uint256[] memory _allUnderlyingPrices = getAllTokenPrices();

//         uint256[] memory _currentBPTPrices = calculateAllPoolPrices(
//             _allUnderlyingPrices
//         );

//         weights._zeroArray = new uint256[](_BPTokensIn.length);
//         for (uint256 i = 0; i < _BPTokensIn.length; i++) {
//             weights._zeroArray[i] = 0;
//         }

//         (
//             weights._idealWeights,
//             weights._currentWeights,
//             weights._hypotheticalWeights,
//             weights._nav,
//             weights._totalPortfolioValue
//         ) = calculateAllWeights(
//             _currentBPTPrices,
//             _BPTokensIn,
//             _amountsIn,
//             weights._zeroArray
//         );

//         bool _safeToMint = safeToMint(
//             _BPTokensIn,
//             weights._hypotheticalWeights,
//             weights._idealWeights,
//             _allUnderlyingPrices,
//             _amountsIn,
//             _currentBPTPrices,
//             weights._currentWeights
//         );

//         if (!_safeToMint) {
//             errorCode |= WOULD_UNBALANCE_GYROSCOPE;
//         }

//         weights._dollarValue = 0;

//         for (uint256 i = 0; i < _BPTokensIn.length; i++) {
//             weights._dollarValue = weights._dollarValue.add(
//                 _amountsIn[i].scaledMul(_currentBPTPrices[i])
//             );
//         }

//         flowLogger = initializeFlowLogger();

//         weights.gyroAmount = gyroPriceOracle.getAmountToMint(
//             weights._dollarValue,
//             flowLogger.inflowHistory,
//             weights._nav
//         );

//         if (weights.gyroAmount < _minGyroMinted) {
//             errorCode |= TOO_MUCH_SLIPPAGE;
//         }

//         return (errorCode, weights, flowLogger);
//     }

//     function safeToMint(
//         address[] memory _BPTokensIn,
//         uint256[] memory _hypotheticalWeights,
//         uint256[] memory _idealWeights,
//         uint256[] memory _allUnderlyingPrices,
//         uint256[] memory _amountsIn,
//         uint256[] memory _currentBPTPrices,
//         uint256[] memory _currentWeights
//     ) internal view returns (bool _launch) {
//         _launch = false;

//         PoolStatus memory poolStatus;

//         (
//             poolStatus._allPoolsHealthy,
//             poolStatus._allPoolsWithinEpsilon,
//             poolStatus._inputPoolHealth,
//             poolStatus._poolsWithinEpsilon
//         ) = checkAllPoolsHealthy(
//             _BPTokensIn,
//             _hypotheticalWeights,
//             _idealWeights,
//             _allUnderlyingPrices
//         );

//         // if check 1 succeeds and all pools healthy, then proceed with minting
//         if (poolStatus._allPoolsHealthy) {
//             if (poolStatus._allPoolsWithinEpsilon) {
//                 _launch = true;
//             }
//         } else {
//             // calculate proportional values of assets user wants to pay with
//             (
//                 uint256[] memory _inputBPTWeights,
//                 uint256 _totalPortfolioValue
//             ) = calculatePortfolioWeights(_amountsIn, _currentBPTPrices);
//             if (_totalPortfolioValue == 0) {
//                 _inputBPTWeights = _idealWeights;
//             }

//             //Check that unhealthy pools have input weight below ideal weight. If true, mint
//             if (poolStatus._allPoolsWithinEpsilon) {
//                 _launch = checkUnhealthyMovesToIdeal(
//                     _BPTokensIn,
//                     poolStatus._inputPoolHealth,
//                     _inputBPTWeights,
//                     _idealWeights
//                 );
//             }
//             //Outside of the epsilon boundary
//             else {
//                 _launch = safeToMintOutsideEpsilon(
//                     _BPTokensIn,
//                     poolStatus._inputPoolHealth,
//                     _inputBPTWeights,
//                     _idealWeights,
//                     _hypotheticalWeights,
//                     _currentWeights,
//                     poolStatus._poolsWithinEpsilon
//                 );
//             }
//         }

//         return _launch;
//     }

//     function redeemChecksPass(
//         address[] memory _BPTokensOut,
//         uint256[] memory _amountsOut,
//         uint256 _maxGyroRedeemed
//     )
//         public
//         view
//         override
//         returns (uint256 errorCode, uint256 estimatedAmount)
//     {
//         (
//             uint256 _errorCode,
//             Weights memory weights,

//         ) = redeemChecksPassInternal(
//                 _BPTokensOut,
//                 _amountsOut,
//                 _maxGyroRedeemed
//             );
//         return (_errorCode, weights.gyroAmount);
//     }

//     function redeemChecksPassInternal(
//         address[] memory _BPTokensOut,
//         uint256[] memory _amountsOut,
//         uint256 _maxGyroRedeemed
//     )
//         internal
//         view
//         returns (
//             uint256 errorCode,
//             Weights memory weights,
//             FlowLogger memory flowLogger
//         )
//     {
//         require(
//             _BPTokensOut.length == _amountsOut.length,
//             "tokensIn and valuesIn should have the same number of elements"
//         );

//         //Filter 1: Require that the tokens are supported and in correct order
//         require(
//             checkBPTokenOrder(_BPTokensOut),
//             "Input tokens in wrong order or contains invalid tokens"
//         );

//         weights._zeroArray = new uint256[](_BPTokensOut.length);
//         for (uint256 i = 0; i < _BPTokensOut.length; i++) {
//             weights._zeroArray[i] = 0;
//         }

//         uint256[] memory _allUnderlyingPrices = getAllTokenPrices();

//         uint256[] memory _currentBPTPrices = calculateAllPoolPrices(
//             _allUnderlyingPrices
//         );

//         (
//             weights._idealWeights,
//             weights._currentWeights,
//             weights._hypotheticalWeights,
//             weights._nav,
//             weights._totalPortfolioValue
//         ) = calculateAllWeights(
//             _currentBPTPrices,
//             _BPTokensOut,
//             weights._zeroArray,
//             _amountsOut
//         );

//         bool _safeToRedeem = safeToRedeem(
//             _BPTokensOut,
//             weights._hypotheticalWeights,
//             weights._idealWeights,
//             weights._currentWeights
//         );

//         if (!_safeToRedeem) {
//             errorCode |= WOULD_UNBALANCE_GYROSCOPE;
//         }

//         weights._dollarValue = 0;

//         for (uint256 i = 0; i < _BPTokensOut.length; i++) {
//             weights._dollarValue = weights._dollarValue.add(
//                 _amountsOut[i].scaledMul(_currentBPTPrices[i])
//             );
//         }

//         flowLogger = initializeFlowLogger();

//         weights.gyroAmount = gyroPriceOracle.getAmountToRedeem(
//             weights._dollarValue,
//             flowLogger.outflowHistory,
//             weights._nav
//         );

//         if (weights.gyroAmount > _maxGyroRedeemed) {
//             errorCode |= TOO_MUCH_SLIPPAGE;
//         }

//         return (errorCode, weights, flowLogger);
//     }

//     function safeToRedeem(
//         address[] memory _BPTokensOut,
//         uint256[] memory _hypotheticalWeights,
//         uint256[] memory _idealWeights,
//         uint256[] memory _currentWeights
//     ) internal view returns (bool) {
//         bool _launch = false;
//         bool _allPoolsWithinEpsilon;
//         bool[] memory _poolsWithinEpsilon = new bool[](_BPTokensOut.length);

//         (_allPoolsWithinEpsilon, _poolsWithinEpsilon) = checkPoolsWithinEpsilon(
//             _BPTokensOut,
//             _hypotheticalWeights,
//             _idealWeights
//         );
//         if (_allPoolsWithinEpsilon) {
//             _launch = true;
//             return _launch;
//         }

//         // check if weights that are beyond epsilon boundary are closer to ideal than current weights
//         bool _checkFail = false;
//         for (uint256 i; i < _BPTokensOut.length; i++) {
//             if (!_poolsWithinEpsilon[i]) {
//                 // check if _hypotheticalWeights[i] is closer to _idealWeights[i] than _currentWeights[i]
//                 uint256 _distanceHypotheticalToIdeal = absValueSub(
//                     _hypotheticalWeights[i],
//                     _idealWeights[i]
//                 );
//                 uint256 _distanceCurrentToIdeal = absValueSub(
//                     _currentWeights[i],
//                     _idealWeights[i]
//                 );

//                 if (_distanceHypotheticalToIdeal >= _distanceCurrentToIdeal) {
//                     _checkFail = true;
//                     break;
//                 }
//             }
//         }

//         if (!_checkFail) {
//             _launch = true;
//         }

//         return _launch;
//     }
// }
