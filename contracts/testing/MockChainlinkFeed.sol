// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

contract MockChainlinkFeed {
    uint8 public immutable decimals;

    struct RoundData {
        int256 price;
        uint256 lastUpdate;
    }

    RoundData[] internal rounds;

    constructor(
        uint8 _decimals,
        int256 _price,
        uint256 _lastUpdate
    ) {
        decimals = _decimals;
        postRound(_price, _lastUpdate);
    }

    function postRound(int256 _price, uint256 _lastUpdate) public {
        rounds.push(RoundData(_price, _lastUpdate));
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return getRoundData(uint80(rounds.length - 1));
    }

    function getRoundData(uint80 _roundId)
        public
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        RoundData memory round = rounds[_roundId];
        return (_roundId, round.price, round.lastUpdate, round.lastUpdate, 0);
    }
}
